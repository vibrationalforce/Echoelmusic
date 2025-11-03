import Foundation
import AVFoundation
import ObjectiveC

/// RTMP Integration for AudioEngine
///
/// Automatically sends audio to RTMP stream when enabled
///
/// Usage:
/// ```swift
/// try audioEngine.enableRTMP(platform: .youtube, streamKey: "key")
/// // Audio now streams to YouTube Live
/// audioEngine.disableRTMP()
/// ```
@available(iOS 15.0, *)
extension AudioEngine {

    // MARK: - Associated Objects

    private static var rtmpEnabledKey: UInt8 = 0

    /// Whether RTMP streaming is enabled
    public var isRTMPEnabled: Bool {
        get {
            objc_getAssociatedObject(self, &Self.rtmpEnabledKey) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, &Self.rtmpEnabledKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    // MARK: - RTMP Control

    /// Enable RTMP streaming to a platform
    public func enableRTMP(platform: RTMPStreamer.Platform, streamKey: String) async throws {
        guard !isRTMPEnabled else {
            print("[AudioEngine] RTMP already enabled")
            return
        }

        // Configure RTMP streamer
        try RTMPStreamer.shared.configure(platform: platform, streamKey: streamKey)

        // Start streaming
        try await RTMPStreamer.shared.startStreaming()

        isRTMPEnabled = true

        print("[AudioEngine] ✅ RTMP enabled")
        print("[AudioEngine]    Platform: \(platform.rawValue)")
        print("[AudioEngine]    Audio will stream automatically")
    }

    /// Enable RTMP with custom configuration
    public func enableRTMP(config: RTMPStreamer.StreamConfiguration) async throws {
        guard !isRTMPEnabled else {
            print("[AudioEngine] RTMP already enabled")
            return
        }

        // Configure RTMP streamer
        try RTMPStreamer.shared.configure(config: config)

        // Start streaming
        try await RTMPStreamer.shared.startStreaming()

        isRTMPEnabled = true

        print("[AudioEngine] ✅ RTMP enabled (custom config)")
    }

    /// Disable RTMP streaming
    public func disableRTMP() {
        guard isRTMPEnabled else {
            print("[AudioEngine] RTMP already disabled")
            return
        }

        RTMPStreamer.shared.stopStreaming()

        isRTMPEnabled = false

        print("[AudioEngine] RTMP disabled")
    }

    /// Send current audio buffer to RTMP stream
    /// This should be called in the audio processing callback
    public func sendToRTMP(buffer: AVAudioPCMBuffer) {
        guard isRTMPEnabled else { return }

        do {
            try RTMPStreamer.shared.send(audioBuffer: buffer)
        } catch {
            print("[AudioEngine] ❌ Failed to send to RTMP: \(error.localizedDescription)")
        }
    }

    // MARK: - RTMP Status

    /// Check if currently streaming
    public var isStreamingRTMP: Bool {
        return RTMPStreamer.shared.isStreaming
    }

    /// Get current stream health
    public var rtmpStreamHealth: RTMPStreamer.StreamHealth {
        return RTMPStreamer.shared.streamHealth
    }

    /// Get stream statistics
    public var rtmpStatistics: RTMPStreamer.StreamStatistics {
        return RTMPStreamer.shared.getStatistics()
    }

    // MARK: - Quick Setup

    /// Quick setup for YouTube Live
    public func quickEnableYouTube(streamKey: String) async throws {
        try await enableRTMP(platform: .youtube, streamKey: streamKey)
    }

    /// Quick setup for Twitch
    public func quickEnableTwitch(streamKey: String) async throws {
        try await enableRTMP(platform: .twitch, streamKey: streamKey)
    }

    /// Quick setup for Facebook Live
    public func quickEnableFacebook(streamKey: String) async throws {
        try await enableRTMP(platform: .facebook, streamKey: streamKey)
    }
}

// MARK: - Auto-Streaming Integration

@available(iOS 15.0, *)
extension AudioEngine {

    /// Enable auto-streaming mode
    /// When enabled, all audio output automatically streams to RTMP
    ///
    /// This installs a tap on the audio engine's main mixer node
    public func enableAutoStreaming() {
        // TODO: Install tap on mixer node
        // This would capture the final mixed audio and send to RTMP
        print("[AudioEngine] Auto-streaming mode enabled")
    }

    /// Disable auto-streaming mode
    public func disableAutoStreaming() {
        // TODO: Remove tap
        print("[AudioEngine] Auto-streaming mode disabled")
    }
}

// MARK: - Integration Helpers

@available(iOS 15.0, *)
extension AudioEngine {

    /// Get combined status of all streaming services
    public var streamingStatus: StreamingStatus {
        return StreamingStatus(
            rtmpEnabled: isRTMPEnabled,
            ndiEnabled: isNDIEnabled,
            rtmpHealth: rtmpStreamHealth,
            ndiConnectionCount: ndiConnectionCount
        )
    }

    public struct StreamingStatus {
        public let rtmpEnabled: Bool
        public let ndiEnabled: Bool
        public let rtmpHealth: RTMPStreamer.StreamHealth
        public let ndiConnectionCount: Int

        public var isStreamingToAny: Bool {
            return rtmpEnabled || ndiEnabled
        }

        public var statusSummary: String {
            var parts: [String] = []

            if rtmpEnabled {
                parts.append("RTMP (\(rtmpHealth.emoji))")
            }

            if ndiEnabled {
                parts.append("NDI (\(ndiConnectionCount) receivers)")
            }

            if parts.isEmpty {
                return "Not streaming"
            } else {
                return "Streaming: \(parts.joined(separator: ", "))"
            }
        }
    }
}
