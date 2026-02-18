// BroadcastEquipmentRegistry.swift
// Echoelmusic - λ Lambda Mode
//
// Broadcast and streaming equipment registry
// Video switchers, streaming platforms, and protocols

import Foundation

// MARK: - Broadcast Equipment Registry

public final class BroadcastEquipmentRegistry {

    public enum SwitcherType: String, CaseIterable {
        case atem = "ATEM"
        case tricaster = "TriCaster"
        case vmix = "vMix"
        case obs = "OBS"
        case wirecast = "Wirecast"
        case streamYard = "StreamYard"
        case ecamm = "Ecamm Live"
        case castr = "Castr"
        case restream = "Restream"
    }

    public struct VideoSwitcher: Identifiable, Hashable {
        public let id: UUID
        public let type: SwitcherType
        public let model: String
        public let inputs: Int
        public let outputs: Int
        public let maxResolution: VideoHardwareRegistry.VideoFormat
        public let hasStreaming: Bool
        public let hasRecording: Bool
        public let hasNDI: Bool
        public let platforms: [DevicePlatform]

        public init(
            id: UUID = UUID(),
            type: SwitcherType,
            model: String,
            inputs: Int,
            outputs: Int,
            maxResolution: VideoHardwareRegistry.VideoFormat,
            hasStreaming: Bool = true,
            hasRecording: Bool = true,
            hasNDI: Bool = false,
            platforms: [DevicePlatform] = [.macOS, .windows]
        ) {
            self.id = id
            self.type = type
            self.model = model
            self.inputs = inputs
            self.outputs = outputs
            self.maxResolution = maxResolution
            self.hasStreaming = hasStreaming
            self.hasRecording = hasRecording
            self.hasNDI = hasNDI
            self.platforms = platforms
        }
    }

    /// Video switchers
    public let switchers: [VideoSwitcher] = [
        // Blackmagic ATEM
        VideoSwitcher(type: .atem, model: "ATEM Mini", inputs: 4, outputs: 1,
                     maxResolution: .hd1080p, hasNDI: false),
        VideoSwitcher(type: .atem, model: "ATEM Mini Pro", inputs: 4, outputs: 2,
                     maxResolution: .hd1080p, hasNDI: false),
        VideoSwitcher(type: .atem, model: "ATEM Mini Pro ISO", inputs: 4, outputs: 2,
                     maxResolution: .hd1080p, hasNDI: false),
        VideoSwitcher(type: .atem, model: "ATEM Mini Extreme", inputs: 8, outputs: 3,
                     maxResolution: .hd1080p, hasNDI: false),
        VideoSwitcher(type: .atem, model: "ATEM Mini Extreme ISO G2", inputs: 8, outputs: 3,
                     maxResolution: .hd1080p, hasNDI: false),
        VideoSwitcher(type: .atem, model: "ATEM Television Studio HD8", inputs: 8, outputs: 4,
                     maxResolution: .hd1080p, hasNDI: false),
        VideoSwitcher(type: .atem, model: "ATEM Television Studio HD8 ISO", inputs: 8, outputs: 4,
                     maxResolution: .hd1080p, hasNDI: false),
        VideoSwitcher(type: .atem, model: "ATEM Constellation 8K", inputs: 40, outputs: 24,
                     maxResolution: .uhd8k, hasNDI: false),

        // Software Switchers
        VideoSwitcher(type: .vmix, model: "vMix Basic HD", inputs: 4, outputs: 3,
                     maxResolution: .hd1080p, hasNDI: true, platforms: [.windows]),
        VideoSwitcher(type: .vmix, model: "vMix HD", inputs: 1000, outputs: 3,
                     maxResolution: .hd1080p, hasNDI: true, platforms: [.windows]),
        VideoSwitcher(type: .vmix, model: "vMix 4K", inputs: 1000, outputs: 3,
                     maxResolution: .uhd4k, hasNDI: true, platforms: [.windows]),
        VideoSwitcher(type: .vmix, model: "vMix Pro", inputs: 1000, outputs: 3,
                     maxResolution: .uhd4k, hasNDI: true, platforms: [.windows]),

        VideoSwitcher(type: .obs, model: "OBS Studio", inputs: 99, outputs: 1,
                     maxResolution: .uhd8k, hasNDI: true, platforms: [.macOS, .windows, .linux]),

        VideoSwitcher(type: .wirecast, model: "Wirecast Studio", inputs: 12, outputs: 3,
                     maxResolution: .uhd4k, hasNDI: true),
        VideoSwitcher(type: .wirecast, model: "Wirecast Pro", inputs: 64, outputs: 3,
                     maxResolution: .uhd4k, hasNDI: true),

        VideoSwitcher(type: .ecamm, model: "Ecamm Live", inputs: 99, outputs: 1,
                     maxResolution: .uhd4k, hasNDI: true, platforms: [.macOS]),

        // NewTek TriCaster
        VideoSwitcher(type: .tricaster, model: "TriCaster Mini", inputs: 4, outputs: 4,
                     maxResolution: .hd1080p, hasNDI: true),
        VideoSwitcher(type: .tricaster, model: "TriCaster 2 Elite", inputs: 32, outputs: 8,
                     maxResolution: .uhd4k, hasNDI: true),
    ]

    /// Streaming platforms
    public let streamingPlatforms: [(name: String, rtmpUrl: String, maxBitrate: Int)] = [
        ("YouTube Live", "rtmp://a.rtmp.youtube.com/live2", 51000),
        ("Twitch", "rtmp://live.twitch.tv/app", 8500),
        ("Facebook Live", "rtmps://live-api-s.facebook.com:443/rtmp", 8000),
        ("Instagram Live", "rtmps://live-upload.instagram.com:443/rtmp", 3500),
        ("TikTok Live", "rtmp://push.tiktokv.com/live", 6000),
        ("X (Twitter) Live", "rtmp://rtmp.pscp.tv:80/x", 2500),
        ("Vimeo Live", "rtmps://rtmp-global.cloud.vimeo.com:443/live", 20000),
        ("Restream", "rtmp://live.restream.io/live", 51000),
        ("Castr", "rtmp://live.castr.io/static", 51000),
    ]

    /// Streaming protocols
    public let streamingProtocols: [(name: String, latency: String, reliability: String)] = [
        ("RTMP", "2-5 seconds", "Good"),
        ("RTMPS", "2-5 seconds", "Excellent (encrypted)"),
        ("SRT", "< 1 second", "Excellent"),
        ("WebRTC", "< 500ms", "Good"),
        ("HLS", "6-30 seconds", "Excellent"),
        ("RIST", "< 1 second", "Excellent"),
        ("NDI", "< 1 frame", "Excellent (LAN only)"),
        ("NDI|HX", "1-2 frames", "Good"),
        ("NDI|HX2", "< 1 frame", "Excellent"),
        ("NDI|HX3", "< 1 frame", "Excellent"),
    ]
}
