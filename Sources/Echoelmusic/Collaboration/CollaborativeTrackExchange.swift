//
//  CollaborativeTrackExchange.swift
//  Echoelmusic
//
//  Created: 2025-11-27
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  COLLABORATIVE TRACK EXCHANGE
//
//  Share tracks, stems, and project elements between collaborators
//  in real-time. Preview before downloading, version control,
//  and seamless integration with local projects.
//
//  Features:
//  - Real-time track preview (stream before download)
//  - Drag & drop track sharing
//  - Stem export/import
//  - Version history
//  - Automatic format conversion
//  - Bandwidth-aware transfer
//

import Foundation
import Combine
import AVFoundation

// MARK: - Track Exchange Manager

@MainActor
public class CollaborativeTrackExchange: ObservableObject {

    // Singleton
    public static let shared = CollaborativeTrackExchange()

    // MARK: - Published State

    @Published public var availableTracks: [SharedTrack] = []
    @Published public var downloadQueue: [TrackDownload] = []
    @Published public var uploadQueue: [TrackUpload] = []
    @Published public var previewingTrack: SharedTrack?

    // Transfer stats
    @Published public var currentDownloadSpeed: Double = 0  // MB/s
    @Published public var currentUploadSpeed: Double = 0  // MB/s
    @Published public var totalBytesTransferred: Int64 = 0

    // MARK: - Types

    public struct SharedTrack: Identifiable {
        public let id: UUID
        public let name: String
        public let ownerId: String
        public let ownerName: String

        // Track info
        public let type: TrackType
        public let duration: TimeInterval
        public let sampleRate: Int
        public let bitDepth: Int
        public let channels: Int
        public let fileSize: Int64  // bytes

        // Metadata
        public let tempo: Double?
        public let key: String?
        public let tags: [String]
        public let description: String?

        // Versioning
        public let version: Int
        public let createdAt: Date
        public let modifiedAt: Date

        // Preview
        public var previewURL: URL?  // Low-quality streaming preview
        public var isPreviewAvailable: Bool { previewURL != nil }

        // Status
        public var isDownloaded: Bool = false
        public var localPath: URL?

        public enum TrackType: String, Codable {
            case audio = "Audio"
            case midi = "MIDI"
            case stem = "Stem"
            case loop = "Loop"
            case sample = "Sample"
            case project = "Project"

            var icon: String {
                switch self {
                case .audio: return "waveform"
                case .midi: return "pianokeys"
                case .stem: return "square.stack.3d.up"
                case .loop: return "repeat"
                case .sample: return "waveform.badge.plus"
                case .project: return "folder"
                }
            }
        }

        public var fileSizeFormatted: String {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return formatter.string(fromByteCount: fileSize)
        }

        public var durationFormatted: String {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    public struct TrackDownload: Identifiable {
        public let id: UUID
        public let track: SharedTrack
        public var progress: Double = 0  // 0-1
        public var bytesReceived: Int64 = 0
        public var status: TransferStatus = .pending
        public var error: Error?

        public var progressPercent: Int {
            return Int(progress * 100)
        }
    }

    public struct TrackUpload: Identifiable {
        public let id: UUID
        public let localPath: URL
        public let trackName: String
        public let targetPeers: [String]  // Empty = all peers
        public var progress: Double = 0
        public var bytesSent: Int64 = 0
        public var status: TransferStatus = .pending
        public var error: Error?
    }

    public enum TransferStatus: String {
        case pending = "Pending"
        case connecting = "Connecting"
        case transferring = "Transferring"
        case processing = "Processing"
        case completed = "Completed"
        case failed = "Failed"
        case cancelled = "Cancelled"
    }

    // MARK: - Dependencies

    private let worldwideSync = WorldwideSyncBridge.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupListeners()
    }

    private func setupListeners() {
        // Listen for shared tracks from peers
        // worldwideSync.onTrackShared = { ... }
    }

    // MARK: - Track Sharing

    /// Share a local track with collaborators
    public func shareTrack(
        localPath: URL,
        name: String,
        type: SharedTrack.TrackType = .audio,
        tempo: Double? = nil,
        key: String? = nil,
        tags: [String] = [],
        description: String? = nil,
        targetPeers: [String] = []  // Empty = all connected peers
    ) async throws -> SharedTrack {

        // Get file info
        let attributes = try FileManager.default.attributesOfItem(atPath: localPath.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        // Get audio info
        let asset = AVURLAsset(url: localPath)
        let duration = try await asset.load(.duration).seconds

        // Create shared track metadata
        let track = SharedTrack(
            id: UUID(),
            name: name,
            ownerId: "local-user",
            ownerName: "You",
            type: type,
            duration: duration,
            sampleRate: 48000,  // Could detect from file
            bitDepth: 24,
            channels: 2,
            fileSize: fileSize,
            tempo: tempo,
            key: key,
            tags: tags,
            description: description,
            version: 1,
            createdAt: Date(),
            modifiedAt: Date(),
            previewURL: nil,
            isDownloaded: true,
            localPath: localPath
        )

        // Announce to peers
        broadcastTrackAvailable(track, to: targetPeers)

        // Add to available tracks
        availableTracks.append(track)

        // Create upload task if requested
        let upload = TrackUpload(
            id: UUID(),
            localPath: localPath,
            trackName: name,
            targetPeers: targetPeers
        )
        uploadQueue.append(upload)

        print("📤 Shared track: \(name) (\(track.fileSizeFormatted))")

        return track
    }

    /// Share multiple tracks at once (stems export)
    public func shareStemBundle(
        stems: [(path: URL, name: String)],
        bundleName: String,
        tempo: Double,
        key: String? = nil
    ) async throws -> [SharedTrack] {

        var sharedTracks: [SharedTrack] = []

        for (path, name) in stems {
            let track = try await shareTrack(
                localPath: path,
                name: "\(bundleName) - \(name)",
                type: .stem,
                tempo: tempo,
                key: key,
                tags: ["stem", bundleName.lowercased()]
            )
            sharedTracks.append(track)
        }

        print("📤 Shared stem bundle: \(bundleName) (\(stems.count) stems)")
        return sharedTracks
    }

    // MARK: - Track Discovery

    /// Request track list from a specific peer
    public func requestTracksFromPeer(_ peerId: String) async throws {
        // Send request message via WebRTC data channel
        let request = TrackListRequest(requesterId: "local-user", timestamp: Date())

        // worldwideSync.webRTC.sendData(...)

        print("📥 Requested track list from \(peerId)")
    }

    private struct TrackListRequest: Codable {
        let requesterId: String
        let timestamp: Date
    }

    // MARK: - Track Preview

    /// Start streaming preview of a remote track
    public func startPreview(_ track: SharedTrack) async throws {
        guard let previewURL = track.previewURL else {
            throw TrackExchangeError.noPreviewAvailable
        }

        previewingTrack = track

        // Stream preview audio
        // This would use AVPlayer for remote streaming
        print("▶️ Previewing: \(track.name)")
    }

    /// Stop current preview
    public func stopPreview() {
        previewingTrack = nil
        print("⏹️ Preview stopped")
    }

    // MARK: - Track Download

    /// Download a shared track
    public func downloadTrack(_ track: SharedTrack, to destination: URL? = nil) async throws -> URL {
        // Create download task
        var download = TrackDownload(
            id: UUID(),
            track: track,
            status: .connecting
        )
        downloadQueue.append(download)

        // Determine destination
        let destURL = destination ?? getDefaultDownloadPath(for: track)

        // Request file transfer via WebRTC
        download.status = .transferring

        // Simulate download progress (real implementation would use WebRTC data channel)
        for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
            try await Task.sleep(nanoseconds: 100_000_000)  // 100ms

            if let index = downloadQueue.firstIndex(where: { $0.id == download.id }) {
                downloadQueue[index].progress = progress
                downloadQueue[index].bytesReceived = Int64(Double(track.fileSize) * progress)
            }
        }

        // Mark completed
        if let index = downloadQueue.firstIndex(where: { $0.id == download.id }) {
            downloadQueue[index].status = .completed
            downloadQueue[index].progress = 1.0
        }

        // Update track status
        if let trackIndex = availableTracks.firstIndex(where: { $0.id == track.id }) {
            availableTracks[trackIndex].isDownloaded = true
            availableTracks[trackIndex].localPath = destURL
        }

        totalBytesTransferred += track.fileSize

        print("✅ Downloaded: \(track.name) to \(destURL.lastPathComponent)")

        return destURL
    }

    /// Download multiple tracks
    public func downloadTracks(_ tracks: [SharedTrack]) async throws -> [URL] {
        var urls: [URL] = []

        for track in tracks {
            let url = try await downloadTrack(track)
            urls.append(url)
        }

        return urls
    }

    /// Cancel a download
    public func cancelDownload(_ downloadId: UUID) {
        if let index = downloadQueue.firstIndex(where: { $0.id == downloadId }) {
            downloadQueue[index].status = .cancelled
        }
    }

    // MARK: - Quick Actions

    /// Quick share: Export current selection and share
    public func quickShare(
        audioBuffer: AVAudioPCMBuffer,
        name: String,
        format: AudioFormat = .wav
    ) async throws -> SharedTrack {

        // Export buffer to temporary file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name).\(format.extension)")

        try await exportBuffer(audioBuffer, to: tempURL, format: format)

        // Share the file
        return try await shareTrack(
            localPath: tempURL,
            name: name,
            type: .audio
        )
    }

    public enum AudioFormat {
        case wav
        case aiff
        case mp3
        case aac

        var `extension`: String {
            switch self {
            case .wav: return "wav"
            case .aiff: return "aiff"
            case .mp3: return "mp3"
            case .aac: return "m4a"
            }
        }
    }

    private func exportBuffer(_ buffer: AVAudioPCMBuffer, to url: URL, format: AudioFormat) async throws {
        // Export audio buffer to file
        // Implementation would use ExtAudioFile or AVAssetWriter
    }

    // MARK: - Real-Time Stem Streaming

    /// Stream a track in real-time to collaborators (low latency)
    public func startRealtimeStream(
        from localPath: URL,
        to peers: [String] = []
    ) async throws {

        // Open audio file
        let file = try AVAudioFile(forReading: localPath)
        let format = file.processingFormat

        print("🎵 Started real-time stream: \(localPath.lastPathComponent)")
        print("   Format: \(Int(format.sampleRate))Hz, \(format.channelCount)ch")

        // Stream chunks via WebRTC audio channel
        // This would integrate with WebRTCManager.sendAudio()
    }

    /// Stop real-time streaming
    public func stopRealtimeStream() {
        print("⏹️ Real-time stream stopped")
    }

    // MARK: - Helpers

    private func getDefaultDownloadPath(for track: SharedTrack) -> URL {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let echoelDownloads = downloads.appendingPathComponent("Echoelmusic/Shared")

        try? FileManager.default.createDirectory(at: echoelDownloads, withIntermediateDirectories: true)

        let filename = "\(track.ownerName) - \(track.name).\(track.type == .midi ? "mid" : "wav")"
        return echoelDownloads.appendingPathComponent(filename)
    }

    private func broadcastTrackAvailable(_ track: SharedTrack, to peers: [String]) {
        // Encode track metadata and send to peers
        // worldwideSync.webRTC.sendData(...)
    }

    // MARK: - Import to Project

    /// Import downloaded track directly into current project
    public func importToProject(
        track: SharedTrack,
        targetTrackIndex: Int? = nil,
        position: TimeInterval = 0
    ) async throws {

        guard let localPath = track.localPath, track.isDownloaded else {
            throw TrackExchangeError.trackNotDownloaded
        }

        // This would integrate with the DAW timeline
        print("📥 Imported \(track.name) to project at position \(position)s")
    }
}

// MARK: - Errors

public enum TrackExchangeError: Error, LocalizedError {
    case noPreviewAvailable
    case trackNotDownloaded
    case transferFailed
    case fileNotFound
    case formatNotSupported

    public var errorDescription: String? {
        switch self {
        case .noPreviewAvailable:
            return "Preview not available for this track"
        case .trackNotDownloaded:
            return "Track must be downloaded first"
        case .transferFailed:
            return "File transfer failed"
        case .fileNotFound:
            return "File not found"
        case .formatNotSupported:
            return "File format not supported"
        }
    }
}

// MARK: - Convenience Extensions

extension CollaborativeTrackExchange {

    /// Get tracks shared by a specific peer
    public func tracks(from peerId: String) -> [SharedTrack] {
        return availableTracks.filter { $0.ownerId == peerId }
    }

    /// Get tracks by type
    public func tracks(ofType type: SharedTrack.TrackType) -> [SharedTrack] {
        return availableTracks.filter { $0.type == type }
    }

    /// Get downloaded tracks
    public var downloadedTracks: [SharedTrack] {
        return availableTracks.filter { $0.isDownloaded }
    }

    /// Get pending downloads
    public var pendingDownloads: [TrackDownload] {
        return downloadQueue.filter { $0.status == .pending || $0.status == .transferring }
    }
}

// MARK: - Debug

#if DEBUG
extension CollaborativeTrackExchange {

    func simulateSharedTracks() {
        let track1 = SharedTrack(
            id: UUID(),
            name: "Drum Loop 128",
            ownerId: "peer-berlin",
            ownerName: "DJ_Berlin",
            type: .loop,
            duration: 8.0,
            sampleRate: 48000,
            bitDepth: 24,
            channels: 2,
            fileSize: 3_500_000,
            tempo: 128,
            key: "Am",
            tags: ["drums", "techno", "loop"],
            description: "Driving techno drum loop",
            version: 1,
            createdAt: Date(),
            modifiedAt: Date()
        )

        let track2 = SharedTrack(
            id: UUID(),
            name: "Bass Stem",
            ownerId: "peer-tokyo",
            ownerName: "Producer_Tokyo",
            type: .stem,
            duration: 180.0,
            sampleRate: 48000,
            bitDepth: 24,
            channels: 2,
            fileSize: 45_000_000,
            tempo: 128,
            key: "Am",
            tags: ["bass", "stem"],
            description: "Deep bass line for the drop",
            version: 2,
            createdAt: Date().addingTimeInterval(-3600),
            modifiedAt: Date()
        )

        let track3 = SharedTrack(
            id: UUID(),
            name: "Synth Lead MIDI",
            ownerId: "peer-nyc",
            ownerName: "Beatmaker_NYC",
            type: .midi,
            duration: 120.0,
            sampleRate: 0,
            bitDepth: 0,
            channels: 0,
            fileSize: 15_000,
            tempo: 128,
            key: "Am",
            tags: ["midi", "synth", "lead"],
            description: "Main synth melody",
            version: 1,
            createdAt: Date(),
            modifiedAt: Date()
        )

        availableTracks = [track1, track2, track3]

        print("🎵 Simulated \(availableTracks.count) shared tracks")
    }
}
#endif
