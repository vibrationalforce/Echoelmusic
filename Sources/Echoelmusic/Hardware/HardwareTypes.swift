// HardwareTypes.swift
// Echoelmusic - λ Lambda Mode
//
// Hardware type definitions and device models
// Shared enums and structs used across all hardware registries

import Foundation

// MARK: - Ecosystem Status

public enum EcosystemStatus: String, CaseIterable {
    case initializing = "Initializing"
    case ready = "Ready"
    case scanning = "Scanning"
    case connected = "Connected"
    case error = "Error"
}

// MARK: - Connected Device

public struct ConnectedDevice: Identifiable, Hashable {
    public let id: UUID
    public let name: String
    public let type: DeviceType
    public let platform: DevicePlatform
    public let connectionType: ConnectionType
    public let capabilities: Set<DeviceCapability>
    public var isActive: Bool
    public var latencyMs: Double

    public init(
        id: UUID = UUID(),
        name: String,
        type: DeviceType,
        platform: DevicePlatform,
        connectionType: ConnectionType,
        capabilities: Set<DeviceCapability>,
        isActive: Bool = true,
        latencyMs: Double = 0
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.platform = platform
        self.connectionType = connectionType
        self.capabilities = capabilities
        self.isActive = isActive
        self.latencyMs = latencyMs
    }
}

// MARK: - Device Types

public enum DeviceType: String, CaseIterable {
    // Apple Devices
    case iPhone = "iPhone"
    case iPad = "iPad"
    case mac = "Mac"
    case appleWatch = "Apple Watch"
    case appleTv = "Apple TV"
    case visionPro = "Apple Vision Pro"
    case homePod = "HomePod"
    case airPods = "AirPods"

    // Android Devices
    case androidPhone = "Android Phone"
    case androidTablet = "Android Tablet"
    case wearOS = "Wear OS Watch"
    case androidTV = "Android TV"

    // Computers
    case windowsPC = "Windows PC"
    case linuxPC = "Linux PC"

    // VR/AR
    case metaQuest = "Meta Quest"
    case metaGlasses = "Ray-Ban Meta"

    // Automotive
    case tesla = "Tesla"

    // Audio Hardware
    case audioInterface = "Audio Interface"
    case midiController = "MIDI Controller"
    case synthesizer = "Synthesizer"
    case drumMachine = "Drum Machine"

    // Video/Lighting
    case videoSwitcher = "Video Switcher"
    case camera = "Camera"
    case dmxController = "DMX Controller"
    case lightFixture = "Light Fixture"
    case ledStrip = "LED Strip"

    // In-Car Audio Platforms
    case carPlay = "CarPlay"
    case androidAuto = "Android Auto"

    // Smart Home
    case smartLight = "Smart Light"
    case smartSpeaker = "Smart Speaker"
    case smartDisplay = "Smart Display"

    // Other
    case custom = "Custom Device"
}

// MARK: - Device Platform

public enum DevicePlatform: String, CaseIterable {
    // Apple
    case iOS = "iOS"
    case iPadOS = "iPadOS"
    case macOS = "macOS"
    case watchOS = "watchOS"
    case tvOS = "tvOS"
    case visionOS = "visionOS"

    // Google/Android
    case android = "Android"
    case wearOS = "Wear OS"
    case androidTV = "Android TV"
    case androidAuto = "Android Auto"

    // Desktop
    case windows = "Windows"
    case linux = "Linux"

    // Meta
    case questOS = "Quest OS"

    // In-Car Audio Platforms
    case carPlay = "CarPlay"

    // Smart Home
    case homeKit = "HomeKit"
    case googleHome = "Google Home"
    case alexa = "Alexa"
    case matter = "Matter"

    // Embedded
    case embedded = "Embedded"
    case custom = "Custom"
}

// MARK: - Connection Type

public enum ConnectionType: String, CaseIterable {
    // Wired
    case usb = "USB"
    case usbC = "USB-C"
    case thunderbolt = "Thunderbolt"
    case lightning = "Lightning"
    case hdmi = "HDMI"
    case sdi = "SDI"
    case xlr = "XLR"
    case ethernet = "Ethernet"
    case dmx = "DMX"
    case ilda = "ILDA"
    case midi5Pin = "MIDI 5-Pin"

    // Wireless
    case bluetooth = "Bluetooth"
    case bluetoothLE = "Bluetooth LE"
    case wifi = "WiFi"
    case airPlay = "AirPlay"
    case ndi = "NDI"
    case artNet = "Art-Net"
    case sACN = "sACN"
    case osc = "OSC"

    // Protocols
    case rtmp = "RTMP"
    case srt = "SRT"
    case webRTC = "WebRTC"
    case hls = "HLS"
}

// MARK: - Device Capability

public enum DeviceCapability: String, CaseIterable {
    // Audio
    case audioInput = "Audio Input"
    case audioOutput = "Audio Output"
    case midiInput = "MIDI Input"
    case midiOutput = "MIDI Output"
    case spatialAudio = "Spatial Audio"
    case lowLatencyAudio = "Low Latency Audio"

    // Video
    case videoInput = "Video Input"
    case videoOutput = "Video Output"
    case streaming = "Streaming"
    case recording = "Recording"

    // Biometrics
    case heartRate = "Heart Rate"
    case hrv = "HRV"
    case bloodOxygen = "Blood Oxygen"
    case ecg = "ECG"
    case breathing = "Breathing"
    case temperature = "Temperature"

    // Sensors
    case accelerometer = "Accelerometer"
    case gyroscope = "Gyroscope"
    case gps = "GPS"
    case lidar = "LiDAR"
    case faceTracking = "Face Tracking"
    case handTracking = "Hand Tracking"
    case eyeTracking = "Eye Tracking"

    // Display
    case display = "Display"
    case hdr = "HDR"
    case dolbyVision = "Dolby Vision"
    case proMotion = "ProMotion"

    // Lighting
    case dmxControl = "DMX Control"
    case rgbControl = "RGB Control"
    case rgbwControl = "RGBW Control"
    case movingHead = "Moving Head"
    case laser = "Laser"

    // Haptics
    case haptics = "Haptics"
    case forceTouch = "Force Touch"
}

// MARK: - Multi-Device Session

public struct MultiDeviceSession: Identifiable {
    public let id: UUID
    public let name: String
    public var devices: [ConnectedDevice]
    public var syncMode: SyncMode
    public var latencyCompensation: Bool
    public var startTime: Date

    public enum SyncMode: String, CaseIterable {
        case master = "Master"
        case slave = "Slave"
        case peer = "Peer-to-Peer"
        case cloud = "Cloud Sync"
    }

    public init(
        id: UUID = UUID(),
        name: String,
        devices: [ConnectedDevice] = [],
        syncMode: SyncMode = .peer,
        latencyCompensation: Bool = true
    ) {
        self.id = id
        self.name = name
        self.devices = devices
        self.syncMode = syncMode
        self.latencyCompensation = latencyCompensation
        self.startTime = Date()
    }
}
