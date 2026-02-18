// VideoHardwareRegistry.swift
// Echoelmusic - λ Lambda Mode
//
// Video capture hardware registry
// Professional cameras, capture cards, and video formats

import Foundation

// MARK: - Video Hardware Registry

public final class VideoHardwareRegistry {

    public enum CameraBrand: String, CaseIterable {
        case blackmagic = "Blackmagic Design"
        case sony = "Sony"
        case canon = "Canon"
        case panasonic = "Panasonic"
        case red = "RED"
        case arri = "ARRI"
        case ptzOptics = "PTZOptics"
        case birdDog = "BirdDog"
        case logitech = "Logitech"
        case elgato = "Elgato"
        case insta360 = "Insta360"
        case gopro = "GoPro"
        case dji = "DJI"
        case obsbot = "OBSBOT"
    }

    public enum VideoFormat: String, CaseIterable {
        case hd720p = "720p"
        case hd1080p = "1080p"
        case uhd4k = "4K UHD"
        case uhd6k = "6K"
        case uhd8k = "8K"
        case uhd12k = "12K"
        case uhd16k = "16K"
    }

    public enum FrameRate: Int, CaseIterable {
        case fps24 = 24
        case fps25 = 25
        case fps30 = 30
        case fps50 = 50
        case fps60 = 60
        case fps120 = 120
        case fps240 = 240
        case fps1000 = 1000
    }

    public struct Camera: Identifiable, Hashable {
        public let id: UUID
        public let brand: CameraBrand
        public let model: String
        public let maxResolution: VideoFormat
        public let maxFrameRate: FrameRate
        public let connectionTypes: [ConnectionType]
        public let hasNDI: Bool
        public let hasSDI: Bool
        public let isPTZ: Bool

        public init(
            id: UUID = UUID(),
            brand: CameraBrand,
            model: String,
            maxResolution: VideoFormat,
            maxFrameRate: FrameRate,
            connectionTypes: [ConnectionType],
            hasNDI: Bool = false,
            hasSDI: Bool = false,
            isPTZ: Bool = false
        ) {
            self.id = id
            self.brand = brand
            self.model = model
            self.maxResolution = maxResolution
            self.maxFrameRate = maxFrameRate
            self.connectionTypes = connectionTypes
            self.hasNDI = hasNDI
            self.hasSDI = hasSDI
            self.isPTZ = isPTZ
        }
    }

    public struct CaptureCard: Identifiable, Hashable {
        public let id: UUID
        public let brand: String
        public let model: String
        public let inputs: Int
        public let maxResolution: VideoFormat
        public let maxFrameRate: FrameRate
        public let connectionTypes: [ConnectionType]
        public let hasPassthrough: Bool

        public init(
            id: UUID = UUID(),
            brand: String,
            model: String,
            inputs: Int,
            maxResolution: VideoFormat,
            maxFrameRate: FrameRate,
            connectionTypes: [ConnectionType],
            hasPassthrough: Bool = false
        ) {
            self.id = id
            self.brand = brand
            self.model = model
            self.inputs = inputs
            self.maxResolution = maxResolution
            self.maxFrameRate = maxFrameRate
            self.connectionTypes = connectionTypes
            self.hasPassthrough = hasPassthrough
        }
    }

    /// Professional cameras
    public let cameras: [Camera] = [
        // Blackmagic
        Camera(brand: .blackmagic, model: "Pocket Cinema Camera 6K Pro", maxResolution: .uhd6k, maxFrameRate: .fps60,
              connectionTypes: [.hdmi, .usb], hasSDI: false),
        Camera(brand: .blackmagic, model: "URSA Mini Pro 12K", maxResolution: .uhd12k, maxFrameRate: .fps60,
              connectionTypes: [.sdi, .usb], hasSDI: true),
        Camera(brand: .blackmagic, model: "Studio Camera 4K Plus G2", maxResolution: .uhd4k, maxFrameRate: .fps60,
              connectionTypes: [.hdmi, .sdi], hasSDI: true),

        // Sony
        Camera(brand: .sony, model: "FX6", maxResolution: .uhd4k, maxFrameRate: .fps120,
              connectionTypes: [.hdmi, .sdi], hasSDI: true),
        Camera(brand: .sony, model: "a7S III", maxResolution: .uhd4k, maxFrameRate: .fps120,
              connectionTypes: [.hdmi, .usb]),
        Camera(brand: .sony, model: "a1", maxResolution: .uhd8k, maxFrameRate: .fps30,
              connectionTypes: [.hdmi, .usb]),

        // Canon
        Camera(brand: .canon, model: "EOS R5 C", maxResolution: .uhd8k, maxFrameRate: .fps60,
              connectionTypes: [.hdmi, .usb]),
        Camera(brand: .canon, model: "EOS C70", maxResolution: .uhd4k, maxFrameRate: .fps120,
              connectionTypes: [.hdmi, .sdi], hasSDI: true),

        // RED
        Camera(brand: .red, model: "V-RAPTOR XL 8K VV", maxResolution: .uhd8k, maxFrameRate: .fps120,
              connectionTypes: [.sdi], hasSDI: true),

        // PTZ Cameras
        Camera(brand: .ptzOptics, model: "Move 4K", maxResolution: .uhd4k, maxFrameRate: .fps60,
              connectionTypes: [.hdmi, .sdi, .ethernet], hasNDI: true, hasSDI: true, isPTZ: true),
        Camera(brand: .birdDog, model: "P400", maxResolution: .uhd4k, maxFrameRate: .fps60,
              connectionTypes: [.ethernet], hasNDI: true, isPTZ: true),
        Camera(brand: .sony, model: "SRG-A40", maxResolution: .uhd4k, maxFrameRate: .fps60,
              connectionTypes: [.hdmi, .sdi, .ethernet], hasNDI: true, hasSDI: true, isPTZ: true),

        // Webcams / Streaming Cameras
        Camera(brand: .logitech, model: "Brio 4K", maxResolution: .uhd4k, maxFrameRate: .fps60,
              connectionTypes: [.usb]),
        Camera(brand: .logitech, model: "StreamCam", maxResolution: .hd1080p, maxFrameRate: .fps60,
              connectionTypes: [.usbC]),
        Camera(brand: .elgato, model: "Facecam Pro", maxResolution: .uhd4k, maxFrameRate: .fps60,
              connectionTypes: [.usbC]),
        Camera(brand: .obsbot, model: "Tail Air", maxResolution: .uhd4k, maxFrameRate: .fps60,
              connectionTypes: [.hdmi, .usbC, .ethernet], hasNDI: true, isPTZ: true),

        // Action/360 Cameras
        Camera(brand: .insta360, model: "X4", maxResolution: .uhd8k, maxFrameRate: .fps60,
              connectionTypes: [.usbC]),
        Camera(brand: .gopro, model: "HERO12 Black", maxResolution: .uhd4k, maxFrameRate: .fps120,
              connectionTypes: [.usbC]),
        Camera(brand: .dji, model: "Osmo Action 4", maxResolution: .uhd4k, maxFrameRate: .fps120,
              connectionTypes: [.usbC]),
    ]

    /// Capture cards
    public let captureCards: [CaptureCard] = [
        // Blackmagic
        CaptureCard(brand: "Blackmagic", model: "DeckLink Mini Recorder 4K", inputs: 1,
                   maxResolution: .uhd4k, maxFrameRate: .fps60, connectionTypes: [.hdmi, .sdi]),
        CaptureCard(brand: "Blackmagic", model: "DeckLink Quad HDMI Recorder", inputs: 4,
                   maxResolution: .hd1080p, maxFrameRate: .fps60, connectionTypes: [.hdmi]),
        CaptureCard(brand: "Blackmagic", model: "UltraStudio 4K Mini", inputs: 1,
                   maxResolution: .uhd4k, maxFrameRate: .fps60, connectionTypes: [.hdmi, .sdi, .thunderbolt]),

        // Elgato
        CaptureCard(brand: "Elgato", model: "HD60 X", inputs: 1,
                   maxResolution: .uhd4k, maxFrameRate: .fps60, connectionTypes: [.hdmi, .usb], hasPassthrough: true),
        CaptureCard(brand: "Elgato", model: "4K60 Pro MK.2", inputs: 1,
                   maxResolution: .uhd4k, maxFrameRate: .fps60, connectionTypes: [.hdmi], hasPassthrough: true),
        CaptureCard(brand: "Elgato", model: "Cam Link 4K", inputs: 1,
                   maxResolution: .uhd4k, maxFrameRate: .fps30, connectionTypes: [.hdmi, .usb]),

        // AVerMedia
        CaptureCard(brand: "AVerMedia", model: "Live Gamer 4K 2.1", inputs: 1,
                   maxResolution: .uhd4k, maxFrameRate: .fps120, connectionTypes: [.hdmi], hasPassthrough: true),
        CaptureCard(brand: "AVerMedia", model: "Live Gamer Portable 2 Plus", inputs: 1,
                   maxResolution: .uhd4k, maxFrameRate: .fps60, connectionTypes: [.hdmi, .usb], hasPassthrough: true),

        // Magewell
        CaptureCard(brand: "Magewell", model: "USB Capture HDMI 4K Plus", inputs: 1,
                   maxResolution: .uhd4k, maxFrameRate: .fps60, connectionTypes: [.hdmi, .usb]),
        CaptureCard(brand: "Magewell", model: "Pro Capture Quad HDMI", inputs: 4,
                   maxResolution: .hd1080p, maxFrameRate: .fps60, connectionTypes: [.hdmi]),
        CaptureCard(brand: "Magewell", model: "Pro Capture Dual SDI", inputs: 2,
                   maxResolution: .hd1080p, maxFrameRate: .fps60, connectionTypes: [.sdi]),
    ]
}
