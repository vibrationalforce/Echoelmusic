// AudioInterfaceRegistry.swift
// Echoelmusic - λ Lambda Mode
//
// Audio interface hardware registry
// Comprehensive database of professional audio interfaces and driver types

import Foundation

// MARK: - Audio Interface Registry

public final class AudioInterfaceRegistry {

    // MARK: - Professional Audio Interfaces

    public enum AudioInterfaceBrand: String, CaseIterable {
        case universalAudio = "Universal Audio"
        case focusrite = "Focusrite"
        case rme = "RME"
        case motu = "MOTU"
        case apogee = "Apogee"
        case ssl = "SSL"
        case audient = "Audient"
        case presonus = "PreSonus"
        case antelope = "Antelope Audio"
        case steinberg = "Steinberg"
        case zoom = "Zoom"
        case tascam = "TASCAM"
        case behringer = "Behringer"
        case nativeInstruments = "Native Instruments"
        case arturia = "Arturia"
        case ik = "IK Multimedia"
        case mackie = "Mackie"
        case soundcraft = "Soundcraft"
        case yamaha = "Yamaha"
        case roland = "Roland"
    }

    public struct AudioInterface: Identifiable, Hashable {
        public let id: UUID
        public let brand: AudioInterfaceBrand
        public let model: String
        public let inputs: Int
        public let outputs: Int
        public let sampleRates: [Int]
        public let bitDepths: [Int]
        public let connectionTypes: [ConnectionType]
        public let hasPreamps: Bool
        public let hasDSP: Bool
        public let hasMIDI: Bool
        public let platforms: [DevicePlatform]

        public init(
            id: UUID = UUID(),
            brand: AudioInterfaceBrand,
            model: String,
            inputs: Int,
            outputs: Int,
            sampleRates: [Int] = [44100, 48000, 88200, 96000, 176400, 192000],
            bitDepths: [Int] = [16, 24, 32],
            connectionTypes: [ConnectionType],
            hasPreamps: Bool = true,
            hasDSP: Bool = false,
            hasMIDI: Bool = false,
            platforms: [DevicePlatform]
        ) {
            self.id = id
            self.brand = brand
            self.model = model
            self.inputs = inputs
            self.outputs = outputs
            self.sampleRates = sampleRates
            self.bitDepths = bitDepths
            self.connectionTypes = connectionTypes
            self.hasPreamps = hasPreamps
            self.hasDSP = hasDSP
            self.hasMIDI = hasMIDI
            self.platforms = platforms
        }
    }

    /// All supported professional audio interfaces
    public let interfaces: [AudioInterface] = [
        // Universal Audio Apollo Series
        AudioInterface(brand: .universalAudio, model: "Apollo Twin X", inputs: 10, outputs: 6,
                      connectionTypes: [.thunderbolt, .usbC], hasDSP: true, hasMIDI: true,
                      platforms: [.macOS, .windows]),
        AudioInterface(brand: .universalAudio, model: "Apollo x4", inputs: 12, outputs: 18,
                      connectionTypes: [.thunderbolt], hasDSP: true, hasMIDI: true,
                      platforms: [.macOS, .windows]),
        AudioInterface(brand: .universalAudio, model: "Apollo x6", inputs: 16, outputs: 22,
                      connectionTypes: [.thunderbolt], hasDSP: true, hasMIDI: true,
                      platforms: [.macOS, .windows]),
        AudioInterface(brand: .universalAudio, model: "Apollo x8", inputs: 18, outputs: 24,
                      connectionTypes: [.thunderbolt], hasDSP: true, hasMIDI: true,
                      platforms: [.macOS, .windows]),
        AudioInterface(brand: .universalAudio, model: "Apollo x8p", inputs: 18, outputs: 24,
                      connectionTypes: [.thunderbolt], hasDSP: true, hasMIDI: true,
                      platforms: [.macOS, .windows]),
        AudioInterface(brand: .universalAudio, model: "Apollo x16", inputs: 18, outputs: 20,
                      connectionTypes: [.thunderbolt], hasDSP: true, hasMIDI: true,
                      platforms: [.macOS, .windows]),
        AudioInterface(brand: .universalAudio, model: "Apollo Solo", inputs: 2, outputs: 4,
                      connectionTypes: [.thunderbolt, .usb], hasDSP: true,
                      platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .universalAudio, model: "Volt 1", inputs: 1, outputs: 2,
                      connectionTypes: [.usbC], platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .universalAudio, model: "Volt 2", inputs: 2, outputs: 2,
                      connectionTypes: [.usbC], platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .universalAudio, model: "Volt 4", inputs: 4, outputs: 4,
                      connectionTypes: [.usbC], platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .universalAudio, model: "Volt 176", inputs: 2, outputs: 2,
                      connectionTypes: [.usbC], hasDSP: true, platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .universalAudio, model: "Volt 276", inputs: 2, outputs: 2,
                      connectionTypes: [.usbC], hasDSP: true, platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .universalAudio, model: "Volt 476", inputs: 4, outputs: 4,
                      connectionTypes: [.usbC], hasDSP: true, platforms: [.macOS, .windows, .iOS]),

        // Focusrite Scarlett Series
        AudioInterface(brand: .focusrite, model: "Scarlett Solo 4th Gen", inputs: 2, outputs: 2,
                      connectionTypes: [.usbC], platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .focusrite, model: "Scarlett 2i2 4th Gen", inputs: 2, outputs: 2,
                      connectionTypes: [.usbC], platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .focusrite, model: "Scarlett 4i4 4th Gen", inputs: 4, outputs: 4,
                      connectionTypes: [.usbC], hasMIDI: true, platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .focusrite, model: "Scarlett 8i6 3rd Gen", inputs: 8, outputs: 6,
                      connectionTypes: [.usbC], hasMIDI: true, platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .focusrite, model: "Scarlett 18i8 3rd Gen", inputs: 18, outputs: 8,
                      connectionTypes: [.usbC], hasMIDI: true, platforms: [.macOS, .windows]),
        AudioInterface(brand: .focusrite, model: "Scarlett 18i20 3rd Gen", inputs: 18, outputs: 20,
                      connectionTypes: [.usbC], hasMIDI: true, platforms: [.macOS, .windows]),
        // Focusrite Clarett Series
        AudioInterface(brand: .focusrite, model: "Clarett+ 2Pre", inputs: 10, outputs: 4,
                      connectionTypes: [.usbC], hasMIDI: true, platforms: [.macOS, .windows]),
        AudioInterface(brand: .focusrite, model: "Clarett+ 4Pre", inputs: 18, outputs: 8,
                      connectionTypes: [.usbC], hasMIDI: true, platforms: [.macOS, .windows]),
        AudioInterface(brand: .focusrite, model: "Clarett+ 8Pre", inputs: 18, outputs: 20,
                      connectionTypes: [.usbC], hasMIDI: true, platforms: [.macOS, .windows]),

        // RME Series
        AudioInterface(brand: .rme, model: "Babyface Pro FS", inputs: 12, outputs: 12,
                      connectionTypes: [.usb], hasMIDI: true,
                      platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .rme, model: "Fireface UCX II", inputs: 20, outputs: 20,
                      connectionTypes: [.usb], hasDSP: true, hasMIDI: true,
                      platforms: [.macOS, .windows]),
        AudioInterface(brand: .rme, model: "Fireface UFX III", inputs: 94, outputs: 94,
                      sampleRates: [44100, 48000, 88200, 96000, 176400, 192000, 352800, 384000],
                      connectionTypes: [.usb, .thunderbolt], hasDSP: true, hasMIDI: true,
                      platforms: [.macOS, .windows]),
        AudioInterface(brand: .rme, model: "ADI-2 Pro FS R BE", inputs: 4, outputs: 4,
                      sampleRates: [44100, 48000, 88200, 96000, 176400, 192000, 352800, 384000, 705600, 768000],
                      connectionTypes: [.usb], hasDSP: true,
                      platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .rme, model: "MADIface XT", inputs: 394, outputs: 394,
                      connectionTypes: [.usb, .thunderbolt], hasMIDI: true,
                      platforms: [.macOS, .windows]),

        // MOTU Series
        AudioInterface(brand: .motu, model: "M2", inputs: 2, outputs: 2,
                      connectionTypes: [.usbC],
                      platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .motu, model: "M4", inputs: 4, outputs: 4,
                      connectionTypes: [.usbC], hasMIDI: true,
                      platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .motu, model: "M6", inputs: 6, outputs: 4,
                      connectionTypes: [.usbC], hasMIDI: true,
                      platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .motu, model: "UltraLite mk5", inputs: 18, outputs: 22,
                      connectionTypes: [.usbC], hasDSP: true, hasMIDI: true,
                      platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .motu, model: "828es", inputs: 28, outputs: 32,
                      connectionTypes: [.thunderbolt, .usb], hasDSP: true, hasMIDI: true,
                      platforms: [.macOS, .windows]),
        AudioInterface(brand: .motu, model: "1248", inputs: 32, outputs: 34,
                      connectionTypes: [.thunderbolt, .usb, .ethernet], hasDSP: true, hasMIDI: true,
                      platforms: [.macOS, .windows]),
        AudioInterface(brand: .motu, model: "16A", inputs: 32, outputs: 32,
                      connectionTypes: [.thunderbolt, .usb, .ethernet], hasDSP: true,
                      platforms: [.macOS, .windows]),

        // Apogee
        AudioInterface(brand: .apogee, model: "Duet 3", inputs: 2, outputs: 4,
                      connectionTypes: [.usbC], hasDSP: true,
                      platforms: [.macOS, .iOS]),
        AudioInterface(brand: .apogee, model: "Symphony Desktop", inputs: 10, outputs: 14,
                      connectionTypes: [.usbC], hasDSP: true, hasMIDI: true,
                      platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .apogee, model: "Ensemble Thunderbolt", inputs: 30, outputs: 34,
                      connectionTypes: [.thunderbolt], hasDSP: true, hasMIDI: true,
                      platforms: [.macOS]),

        // SSL
        AudioInterface(brand: .ssl, model: "SSL 2", inputs: 2, outputs: 2,
                      connectionTypes: [.usb],
                      platforms: [.macOS, .windows]),
        AudioInterface(brand: .ssl, model: "SSL 2+", inputs: 2, outputs: 4,
                      connectionTypes: [.usb], hasMIDI: true,
                      platforms: [.macOS, .windows]),
        AudioInterface(brand: .ssl, model: "SSL 12", inputs: 12, outputs: 8,
                      connectionTypes: [.usb], hasMIDI: true,
                      platforms: [.macOS, .windows]),

        // Audient
        AudioInterface(brand: .audient, model: "iD4 MKII", inputs: 2, outputs: 2,
                      connectionTypes: [.usbC],
                      platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .audient, model: "iD14 MKII", inputs: 10, outputs: 4,
                      connectionTypes: [.usbC], hasMIDI: true,
                      platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .audient, model: "iD24", inputs: 10, outputs: 14,
                      connectionTypes: [.usbC], hasMIDI: true,
                      platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .audient, model: "iD44 MKII", inputs: 20, outputs: 24,
                      connectionTypes: [.usbC], hasMIDI: true,
                      platforms: [.macOS, .windows]),

        // Antelope Audio
        AudioInterface(brand: .antelope, model: "Zen Go Synergy Core", inputs: 4, outputs: 4,
                      connectionTypes: [.usbC, .thunderbolt], hasDSP: true,
                      platforms: [.macOS, .windows]),
        AudioInterface(brand: .antelope, model: "Discrete 4 Synergy Core", inputs: 12, outputs: 14,
                      connectionTypes: [.thunderbolt, .usb], hasDSP: true, hasMIDI: true,
                      platforms: [.macOS, .windows]),
        AudioInterface(brand: .antelope, model: "Discrete 8 Synergy Core", inputs: 26, outputs: 30,
                      connectionTypes: [.thunderbolt, .usb], hasDSP: true, hasMIDI: true,
                      platforms: [.macOS, .windows]),
        AudioInterface(brand: .antelope, model: "Orion 32+ Gen 4", inputs: 64, outputs: 64,
                      connectionTypes: [.thunderbolt, .usb], hasDSP: true,
                      platforms: [.macOS, .windows]),

        // PreSonus
        AudioInterface(brand: .presonus, model: "AudioBox GO", inputs: 2, outputs: 2,
                      connectionTypes: [.usbC],
                      platforms: [.macOS, .windows, .iOS, .android]),
        AudioInterface(brand: .presonus, model: "Studio 24c", inputs: 2, outputs: 2,
                      connectionTypes: [.usbC], hasMIDI: true,
                      platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .presonus, model: "Studio 26c", inputs: 2, outputs: 4,
                      connectionTypes: [.usbC], hasMIDI: true,
                      platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .presonus, model: "Studio 68c", inputs: 6, outputs: 6,
                      connectionTypes: [.usbC], hasMIDI: true,
                      platforms: [.macOS, .windows]),
        AudioInterface(brand: .presonus, model: "Studio 1810c", inputs: 18, outputs: 8,
                      connectionTypes: [.usbC], hasMIDI: true,
                      platforms: [.macOS, .windows]),
        AudioInterface(brand: .presonus, model: "Quantum 2626", inputs: 26, outputs: 26,
                      connectionTypes: [.thunderbolt], hasMIDI: true,
                      platforms: [.macOS, .windows]),

        // Steinberg
        AudioInterface(brand: .steinberg, model: "UR22C", inputs: 2, outputs: 2,
                      connectionTypes: [.usbC], hasDSP: true, hasMIDI: true,
                      platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .steinberg, model: "UR44C", inputs: 6, outputs: 4,
                      connectionTypes: [.usbC], hasDSP: true, hasMIDI: true,
                      platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .steinberg, model: "UR-C Series", inputs: 12, outputs: 8,
                      connectionTypes: [.usbC], hasDSP: true, hasMIDI: true,
                      platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .steinberg, model: "AXR4T", inputs: 28, outputs: 24,
                      connectionTypes: [.thunderbolt], hasDSP: true, hasMIDI: true,
                      platforms: [.macOS, .windows]),

        // Native Instruments
        AudioInterface(brand: .nativeInstruments, model: "Komplete Audio 1", inputs: 2, outputs: 2,
                      connectionTypes: [.usb],
                      platforms: [.macOS, .windows]),
        AudioInterface(brand: .nativeInstruments, model: "Komplete Audio 2", inputs: 2, outputs: 2,
                      connectionTypes: [.usb], hasMIDI: true,
                      platforms: [.macOS, .windows]),
        AudioInterface(brand: .nativeInstruments, model: "Komplete Audio 6 MK2", inputs: 6, outputs: 6,
                      connectionTypes: [.usb], hasMIDI: true,
                      platforms: [.macOS, .windows]),

        // Arturia
        AudioInterface(brand: .arturia, model: "MiniFuse 1", inputs: 1, outputs: 2,
                      connectionTypes: [.usbC], hasMIDI: true,
                      platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .arturia, model: "MiniFuse 2", inputs: 2, outputs: 2,
                      connectionTypes: [.usbC], hasMIDI: true,
                      platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .arturia, model: "MiniFuse 4", inputs: 4, outputs: 4,
                      connectionTypes: [.usbC], hasMIDI: true,
                      platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .arturia, model: "AudioFuse 8Pre", inputs: 10, outputs: 10,
                      connectionTypes: [.usbC], hasMIDI: true,
                      platforms: [.macOS, .windows]),
        AudioInterface(brand: .arturia, model: "AudioFuse 16Rig", inputs: 18, outputs: 18,
                      connectionTypes: [.usb], hasDSP: true, hasMIDI: true,
                      platforms: [.macOS, .windows]),

        // Zoom
        AudioInterface(brand: .zoom, model: "UAC-2", inputs: 2, outputs: 2,
                      connectionTypes: [.usb], hasMIDI: true,
                      platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .zoom, model: "UAC-232", inputs: 2, outputs: 2,
                      bitDepths: [32], connectionTypes: [.usbC],
                      platforms: [.macOS, .windows]),
        AudioInterface(brand: .zoom, model: "AMS-44", inputs: 4, outputs: 4,
                      connectionTypes: [.usb],
                      platforms: [.macOS, .windows, .iOS]),

        // Roland
        AudioInterface(brand: .roland, model: "Rubix22", inputs: 2, outputs: 2,
                      connectionTypes: [.usb], hasMIDI: true,
                      platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .roland, model: "Rubix24", inputs: 2, outputs: 4,
                      connectionTypes: [.usb], hasMIDI: true,
                      platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .roland, model: "Rubix44", inputs: 4, outputs: 4,
                      connectionTypes: [.usb], hasMIDI: true,
                      platforms: [.macOS, .windows, .iOS]),
        AudioInterface(brand: .roland, model: "Studio-Capture", inputs: 16, outputs: 10,
                      connectionTypes: [.usb], hasDSP: true, hasMIDI: true,
                      platforms: [.macOS, .windows]),

        // IK Multimedia
        AudioInterface(brand: .ik, model: "iRig Pro Duo I/O", inputs: 2, outputs: 2,
                      connectionTypes: [.usb, .lightning], hasMIDI: true,
                      platforms: [.macOS, .windows, .iOS, .android]),
        AudioInterface(brand: .ik, model: "AXE I/O", inputs: 2, outputs: 5,
                      connectionTypes: [.usb], hasMIDI: true,
                      platforms: [.macOS, .windows]),
        AudioInterface(brand: .ik, model: "AXE I/O Solo", inputs: 2, outputs: 3,
                      connectionTypes: [.usb],
                      platforms: [.macOS, .windows, .iOS]),
    ]

    /// Audio driver types by platform
    public enum AudioDriverType: String, CaseIterable {
        // Apple
        case coreAudio = "Core Audio"
        case avAudioEngine = "AVAudioEngine"
        case audioUnit = "Audio Unit"

        // Windows
        case wasapi = "WASAPI"
        case wasapiExclusive = "WASAPI Exclusive"
        case asio = "ASIO"
        case asio4all = "ASIO4ALL"
        case flexAsio = "FlexASIO"
        case wdm = "WDM"
        case directSound = "DirectSound"
        case mme = "MME"

        // Linux
        case alsa = "ALSA"
        case jack = "JACK"
        case pipeWire = "PipeWire"
        case pulseAudio = "PulseAudio"

        // Android
        case aaudio = "AAudio"
        case oboe = "Oboe"
        case openSLES = "OpenSL ES"

        // Cross-platform
        case portAudio = "PortAudio"
        case rtAudio = "RtAudio"
    }

    /// Recommended driver by platform for lowest latency
    public func recommendedDriver(for platform: DevicePlatform) -> AudioDriverType {
        switch platform {
        case .iOS, .iPadOS, .macOS, .tvOS, .visionOS:
            return .coreAudio
        case .windows:
            return .asio  // Native ASIO support coming late 2025
        case .linux:
            return .pipeWire  // Modern replacement for JACK/PulseAudio
        case .android, .wearOS, .androidTV, .androidAuto:
            return .oboe  // Wraps AAudio/OpenSL ES
        default:
            return .portAudio
        }
    }
}
