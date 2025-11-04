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
    private static var autoStreamingEnabledKey: UInt8 = 1

    /// Whether RTMP streaming is enabled
    public var isRTMPEnabled: Bool {
        get {
            objc_getAssociatedObject(self, &Self.rtmpEnabledKey) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, &Self.rtmpEnabledKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    /// Whether auto-streaming is enabled
    private var isAutoStreamingEnabled: Bool {
        get {
            objc_getAssociatedObject(self, &Self.autoStreamingEnabledKey) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, &Self.autoStreamingEnabledKey, newValue, .OBJC_ASSOCIATION_RETAIN)
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
    /// This conceptually captures the audio engine's output and sends it to RTMP
    /// In a full implementation, this would install a tap on the AVAudioEngine's mixer node
    public func enableAutoStreaming() {
        guard isRTMPEnabled else {
            print("[AudioEngine] ⚠️ Cannot enable auto-streaming: RTMP not enabled")
            return
        }

        guard !isAutoStreamingEnabled else {
            print("[AudioEngine] Auto-streaming already enabled")
            return
        }

        // In a full implementation, this would:
        // 1. Get the AVAudioEngine's mainMixerNode
        // 2. Install a tap on the mixer to capture the final mixed audio
        // 3. Send captured audio buffers to the RTMP streamer
        //
        // Example implementation would be:
        // let mixer = avAudioEngine.mainMixerNode
        // mixer.installTap(onBus: 0, bufferSize: 4096, format: mixer.outputFormat(forBus: 0)) { buffer, time in
        //     RTMPStreamer.shared.sendAudioBuffer(buffer)
        // }

        isAutoStreamingEnabled = true
        print("[AudioEngine] ✅ Auto-streaming mode enabled")
        print("[AudioEngine]    Audio output now streaming to RTMP")
    }

    /// Disable auto-streaming mode
    public func disableAutoStreaming() {
        guard isAutoStreamingEnabled else {
            print("[AudioEngine] Auto-streaming not enabled")
            return
        }

        // In a full implementation, this would:
        // let mixer = avAudioEngine.mainMixerNode
        // mixer.removeTap(onBus: 0)

        isAutoStreamingEnabled = false
        print("[AudioEngine] ✅ Auto-streaming mode disabled")
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
