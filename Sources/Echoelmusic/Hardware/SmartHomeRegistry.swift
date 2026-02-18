// SmartHomeRegistry.swift
// Echoelmusic - λ Lambda Mode
//
// Smart home device registry
// Smart lighting, speakers, and displays for home automation integration

import Foundation

// MARK: - Smart Home Registry

public final class SmartHomeRegistry {

    public enum SmartHomeProtocol: String, CaseIterable {
        case homeKit = "HomeKit"
        case matter = "Matter"
        case thread = "Thread"
        case zigbee = "Zigbee"
        case zwave = "Z-Wave"
        case wifi = "WiFi"
        case bluetooth = "Bluetooth"
        case hue = "Philips Hue"
        case alexa = "Alexa"
        case googleHome = "Google Home"
        case hdmi = "HDMI"
        case airPlay = "AirPlay"
    }

    public struct SmartDevice: Identifiable, Hashable {
        public let id: UUID
        public let brand: String
        public let model: String
        public let category: String
        public let protocols: [SmartHomeProtocol]
        public let capabilities: Set<DeviceCapability>

        public init(
            id: UUID = UUID(),
            brand: String,
            model: String,
            category: String,
            protocols: [SmartHomeProtocol],
            capabilities: Set<DeviceCapability>
        ) {
            self.id = id
            self.brand = brand
            self.model = model
            self.category = category
            self.protocols = protocols
            self.capabilities = capabilities
        }
    }

    /// Smart home devices
    public let devices: [SmartDevice] = [
        // Philips Hue
        SmartDevice(brand: "Philips Hue", model: "White and Color Ambiance", category: "Light",
                   protocols: [.hue, .homeKit, .matter, .zigbee],
                   capabilities: [.rgbControl]),
        SmartDevice(brand: "Philips Hue", model: "Gradient Lightstrip", category: "LED Strip",
                   protocols: [.hue, .homeKit, .matter, .zigbee],
                   capabilities: [.rgbControl]),
        SmartDevice(brand: "Philips Hue", model: "Play Gradient Light Tube", category: "LED Bar",
                   protocols: [.hue, .homeKit, .matter, .zigbee],
                   capabilities: [.rgbControl]),
        SmartDevice(brand: "Philips Hue", model: "Sync Box", category: "Controller",
                   protocols: [.hue, .hdmi],
                   capabilities: [.rgbControl]),

        // Nanoleaf
        SmartDevice(brand: "Nanoleaf", model: "Shapes", category: "LED Panel",
                   protocols: [.homeKit, .matter, .thread, .wifi],
                   capabilities: [.rgbControl]),
        SmartDevice(brand: "Nanoleaf", model: "Lines", category: "LED Bar",
                   protocols: [.homeKit, .matter, .thread, .wifi],
                   capabilities: [.rgbControl]),
        SmartDevice(brand: "Nanoleaf", model: "Elements", category: "LED Panel",
                   protocols: [.homeKit, .matter, .thread, .wifi],
                   capabilities: [.rgbControl]),
        SmartDevice(brand: "Nanoleaf", model: "Essentials Lightstrip", category: "LED Strip",
                   protocols: [.homeKit, .matter, .thread],
                   capabilities: [.rgbControl]),

        // LIFX
        SmartDevice(brand: "LIFX", model: "Color A60", category: "Light",
                   protocols: [.homeKit, .wifi, .alexa, .googleHome],
                   capabilities: [.rgbControl]),
        SmartDevice(brand: "LIFX", model: "Beam", category: "LED Bar",
                   protocols: [.homeKit, .wifi, .alexa, .googleHome],
                   capabilities: [.rgbControl]),
        SmartDevice(brand: "LIFX", model: "Z Strip", category: "LED Strip",
                   protocols: [.homeKit, .wifi, .alexa, .googleHome],
                   capabilities: [.rgbControl]),

        // Govee
        SmartDevice(brand: "Govee", model: "Immersion TV Backlight", category: "LED Strip",
                   protocols: [.wifi, .bluetooth, .alexa, .googleHome],
                   capabilities: [.rgbControl]),
        SmartDevice(brand: "Govee", model: "Glide Wall Light", category: "LED Bar",
                   protocols: [.wifi, .bluetooth, .alexa, .googleHome, .matter],
                   capabilities: [.rgbControl]),
        SmartDevice(brand: "Govee", model: "Curtain Lights", category: "LED Strip",
                   protocols: [.wifi, .bluetooth, .alexa, .googleHome],
                   capabilities: [.rgbControl]),

        // HomePod / Apple TV (for audio sync)
        SmartDevice(brand: "Apple", model: "HomePod", category: "Speaker",
                   protocols: [.homeKit, .airPlay],
                   capabilities: [.audioOutput, .spatialAudio]),
        SmartDevice(brand: "Apple", model: "HomePod mini", category: "Speaker",
                   protocols: [.homeKit, .airPlay, .thread],
                   capabilities: [.audioOutput]),
        SmartDevice(brand: "Apple", model: "Apple TV 4K", category: "Display",
                   protocols: [.homeKit, .airPlay, .thread],
                   capabilities: [.audioOutput, .videoOutput, .spatialAudio, .dolbyVision]),
    ]
}
