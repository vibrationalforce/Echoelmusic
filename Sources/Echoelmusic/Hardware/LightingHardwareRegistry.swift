// LightingHardwareRegistry.swift
// Echoelmusic - λ Lambda Mode
//
// Lighting and DMX hardware registry
// Professional lighting fixtures, DMX controllers, and smart home lighting systems

import Foundation

// MARK: - Lighting Hardware Registry

public final class LightingHardwareRegistry {

    public enum LightingProtocol: String, CaseIterable {
        case dmx512 = "DMX512"
        case artNet = "Art-Net"
        case sACN = "sACN (E1.31)"
        case rdm = "RDM"
        case kiNET = "KiNET"
        case hue = "Philips Hue"
        case nanoleaf = "Nanoleaf"
        case lifx = "LIFX"
        case wled = "WLED"
        case ws2812 = "WS2812/NeoPixel"
        case ilda = "ILDA (Laser)"
        case beyond = "Beyond (Laser)"
    }

    public enum FixtureType: String, CaseIterable {
        case parCan = "PAR Can"
        case movingHead = "Moving Head"
        case movingHeadSpot = "Moving Head Spot"
        case movingHeadWash = "Moving Head Wash"
        case movingHeadBeam = "Moving Head Beam"
        case ledBar = "LED Bar"
        case ledStrip = "LED Strip"
        case ledPanel = "LED Panel"
        case ledPixelBar = "LED Pixel Bar"
        case strobe = "Strobe"
        case fogMachine = "Fog Machine"
        case hazeMachine = "Haze Machine"
        case laser = "Laser"
        case goboProjector = "Gobo Projector"
        case followSpot = "Follow Spot"
        case blinder = "Blinder"
        case cyc = "Cyc Light"
        case fresnel = "Fresnel"
        case ellipsoidal = "Ellipsoidal"
        case ledMatrix = "LED Matrix"
        case smartBulb = "Smart Bulb"
    }

    public struct DMXController: Identifiable, Hashable {
        public let id: UUID
        public let name: String
        public let brand: String
        public let universes: Int
        public let protocols: [LightingProtocol]
        public let connectionTypes: [ConnectionType]
        public let hasRDM: Bool

        public init(
            id: UUID = UUID(),
            name: String,
            brand: String,
            universes: Int,
            protocols: [LightingProtocol],
            connectionTypes: [ConnectionType],
            hasRDM: Bool = false
        ) {
            self.id = id
            self.name = name
            self.brand = brand
            self.universes = universes
            self.protocols = protocols
            self.connectionTypes = connectionTypes
            self.hasRDM = hasRDM
        }
    }

    /// Lighting Fixture definition for individual lights
    public struct LightingFixture: Identifiable, Hashable {
        public let id: UUID
        public let name: String
        public let brand: String
        public let type: FixtureType
        public let channels: Int
        public let protocols: [LightingProtocol]
        public let connectionTypes: [ConnectionType]
        public let hasRGB: Bool
        public let hasRGBW: Bool
        public let hasPanTilt: Bool
        public let hasZoom: Bool

        public init(
            id: UUID = UUID(),
            name: String,
            brand: String,
            type: FixtureType,
            channels: Int,
            protocols: [LightingProtocol],
            connectionTypes: [ConnectionType],
            hasRGB: Bool = false,
            hasRGBW: Bool = false,
            hasPanTilt: Bool = false,
            hasZoom: Bool = false
        ) {
            self.id = id
            self.name = name
            self.brand = brand
            self.type = type
            self.channels = channels
            self.protocols = protocols
            self.connectionTypes = connectionTypes
            self.hasRGB = hasRGB
            self.hasRGBW = hasRGBW
            self.hasPanTilt = hasPanTilt
            self.hasZoom = hasZoom
        }
    }

    /// Supported lighting fixtures
    public let supportedFixtures: [LightingFixture] = [
        // PAR Cans
        LightingFixture(name: "SlimPAR Pro QZ12", brand: "Chauvet DJ", type: .parCan,
                       channels: 9, protocols: [.dmx512], connectionTypes: [.dmx],
                       hasRGB: true, hasRGBW: true),
        LightingFixture(name: "COLORado 1-Quad Zoom", brand: "Chauvet Professional", type: .parCan,
                       channels: 14, protocols: [.dmx512, .artNet, .sACN], connectionTypes: [.dmx, .ethernet],
                       hasRGB: true, hasRGBW: true, hasZoom: true),
        LightingFixture(name: "Source Four LED Series 3", brand: "ETC", type: .parCan,
                       channels: 12, protocols: [.dmx512, .rdm], connectionTypes: [.dmx],
                       hasRGB: true, hasRGBW: true),

        // Moving Heads
        LightingFixture(name: "Maverick MK3 Spot", brand: "Chauvet Professional", type: .movingHeadSpot,
                       channels: 35, protocols: [.dmx512, .artNet, .sACN, .rdm], connectionTypes: [.dmx, .ethernet],
                       hasRGB: true, hasPanTilt: true, hasZoom: true),
        LightingFixture(name: "MAC Aura XB", brand: "Martin", type: .movingHeadWash,
                       channels: 22, protocols: [.dmx512, .artNet, .rdm], connectionTypes: [.dmx, .ethernet],
                       hasRGB: true, hasRGBW: true, hasPanTilt: true, hasZoom: true),
        LightingFixture(name: "Rogue R2X Beam", brand: "Chauvet Professional", type: .movingHeadBeam,
                       channels: 18, protocols: [.dmx512], connectionTypes: [.dmx],
                       hasRGB: true, hasPanTilt: true),

        // LED Bars & Strips
        LightingFixture(name: "COLORband PiX-M ILS", brand: "Chauvet DJ", type: .ledBar,
                       channels: 44, protocols: [.dmx512], connectionTypes: [.dmx],
                       hasRGB: true, hasPanTilt: true),
        LightingFixture(name: "LED Strip WS2812B", brand: "Generic", type: .ledStrip,
                       channels: 3, protocols: [.ws2812], connectionTypes: [.usb],
                       hasRGB: true),

        // Lasers
        LightingFixture(name: "Scorpion Storm RGBY", brand: "Chauvet DJ", type: .laser,
                       channels: 11, protocols: [.dmx512], connectionTypes: [.dmx],
                       hasRGB: true),
        LightingFixture(name: "FB4 Max", brand: "Pangolin", type: .laser,
                       channels: 12, protocols: [.dmx512, .ilda, .beyond], connectionTypes: [.dmx, .ilda, .ethernet],
                       hasRGB: true),

        // Smart Bulbs
        LightingFixture(name: "Hue Color A19", brand: "Philips", type: .smartBulb,
                       channels: 4, protocols: [.hue], connectionTypes: [.ethernet],
                       hasRGB: true),
        LightingFixture(name: "A19 Color", brand: "LIFX", type: .smartBulb,
                       channels: 4, protocols: [.lifx], connectionTypes: [.wifi],
                       hasRGB: true, hasRGBW: true),
        LightingFixture(name: "Canvas", brand: "Nanoleaf", type: .ledPanel,
                       channels: 4, protocols: [.nanoleaf], connectionTypes: [.wifi],
                       hasRGB: true),
    ]

    /// DMX Controllers and Interfaces
    public let controllers: [DMXController] = [
        // Enttec
        DMXController(name: "DMX USB Pro", brand: "ENTTEC", universes: 1,
                     protocols: [.dmx512], connectionTypes: [.usb]),
        DMXController(name: "DMX USB Pro MK2", brand: "ENTTEC", universes: 2,
                     protocols: [.dmx512, .rdm], connectionTypes: [.usb], hasRDM: true),
        DMXController(name: "ODE MK3", brand: "ENTTEC", universes: 2,
                     protocols: [.dmx512, .artNet, .sACN, .rdm], connectionTypes: [.ethernet], hasRDM: true),
        DMXController(name: "Storm 24", brand: "ENTTEC", universes: 24,
                     protocols: [.dmx512, .artNet, .sACN, .rdm], connectionTypes: [.ethernet], hasRDM: true),

        // DMXking
        DMXController(name: "ultraDMX Micro", brand: "DMXking", universes: 1,
                     protocols: [.dmx512], connectionTypes: [.usb]),
        DMXController(name: "ultraDMX2 Pro", brand: "DMXking", universes: 2,
                     protocols: [.dmx512, .rdm], connectionTypes: [.usb], hasRDM: true),
        DMXController(name: "eDMX4 PRO", brand: "DMXking", universes: 4,
                     protocols: [.dmx512, .artNet, .sACN, .rdm], connectionTypes: [.ethernet], hasRDM: true),
        DMXController(name: "LeDMX4 PRO", brand: "DMXking", universes: 4,
                     protocols: [.dmx512, .artNet, .sACN, .kiNET], connectionTypes: [.ethernet]),

        // Chamsys
        DMXController(name: "MagicQ MQ50", brand: "ChamSys", universes: 4,
                     protocols: [.dmx512, .artNet, .sACN], connectionTypes: [.ethernet, .usb]),
        DMXController(name: "MagicQ MQ70", brand: "ChamSys", universes: 12,
                     protocols: [.dmx512, .artNet, .sACN], connectionTypes: [.ethernet, .usb]),
        DMXController(name: "MagicQ MQ80", brand: "ChamSys", universes: 48,
                     protocols: [.dmx512, .artNet, .sACN], connectionTypes: [.ethernet, .usb]),
        DMXController(name: "MagicQ Stadium Connect", brand: "ChamSys", universes: 256,
                     protocols: [.dmx512, .artNet, .sACN], connectionTypes: [.ethernet]),

        // MA Lighting
        DMXController(name: "dot2 onPC", brand: "MA Lighting", universes: 1,
                     protocols: [.dmx512, .artNet, .sACN], connectionTypes: [.usb]),
        DMXController(name: "grandMA3 onPC", brand: "MA Lighting", universes: 2,
                     protocols: [.dmx512, .artNet, .sACN], connectionTypes: [.ethernet]),

        // ETC
        DMXController(name: "Gadget II", brand: "ETC", universes: 2,
                     protocols: [.dmx512, .sACN, .rdm], connectionTypes: [.usb, .ethernet], hasRDM: true),
        DMXController(name: "Response Mk2", brand: "ETC", universes: 4,
                     protocols: [.dmx512, .artNet, .sACN, .rdm], connectionTypes: [.ethernet], hasRDM: true),

        // ArtGate
        DMXController(name: "ArtGate Pro", brand: "Sundrax", universes: 8,
                     protocols: [.dmx512, .artNet, .sACN], connectionTypes: [.ethernet]),
    ]

    /// Smart Home Lighting Systems
    public let smartLightingSystems: [(name: String, protocol: LightingProtocol, maxDevices: Int)] = [
        ("Philips Hue Bridge", .hue, 50),
        ("Philips Hue Bridge v2", .hue, 63),
        ("Nanoleaf Controller", .nanoleaf, 500),
        ("LIFX Cloud", .lifx, 1000),
        ("WLED Controller", .wled, 1500),
    ]

    /// Standard DMX channel mappings
    public struct DMXChannelMap {
        public static let rgbPar: [String: Int] = [
            "red": 1, "green": 2, "blue": 3, "dimmer": 4, "strobe": 5
        ]

        public static let rgbwPar: [String: Int] = [
            "red": 1, "green": 2, "blue": 3, "white": 4, "dimmer": 5, "strobe": 6
        ]

        public static let movingHeadBasic: [String: Int] = [
            "pan": 1, "panFine": 2, "tilt": 3, "tiltFine": 4,
            "speed": 5, "dimmer": 6, "strobe": 7, "red": 8, "green": 9, "blue": 10, "white": 11
        ]

        public static let movingHeadFull: [String: Int] = [
            "pan": 1, "panFine": 2, "tilt": 3, "tiltFine": 4,
            "speed": 5, "dimmer": 6, "shutter": 7, "focus": 8, "zoom": 9,
            "color1": 10, "color2": 11, "gobo1": 12, "gobo1Rotate": 13,
            "gobo2": 14, "prism": 15, "prismRotate": 16, "frost": 17,
            "red": 18, "green": 19, "blue": 20, "white": 21, "amber": 22
        ]
    }
}
