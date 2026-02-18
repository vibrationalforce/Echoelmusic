// MIDIControllerRegistry.swift
// Echoelmusic - λ Lambda Mode
//
// MIDI controller hardware registry
// Comprehensive database of professional MIDI controllers

import Foundation

// MARK: - MIDI Controller Registry

public final class MIDIControllerRegistry {

    public enum MIDIControllerBrand: String, CaseIterable {
        case ableton = "Ableton"
        case novation = "Novation"
        case nativeInstruments = "Native Instruments"
        case akai = "Akai"
        case arturia = "Arturia"
        case roland = "Roland"
        case korg = "Korg"
        case nektar = "Nektar"
        case ikmultimedia = "IK Multimedia"
        case keith = "Keith McMillen"
        case roli = "ROLI"
        case sensel = "Sensel"
        case expressiveE = "Expressive E"
        case lividInstruments = "Livid Instruments"
        case faderfox = "Faderfox"
        case behringer = "Behringer"
    }

    public enum ControllerType: String, CaseIterable {
        case padController = "Pad Controller"
        case keyboard = "Keyboard"
        case faderController = "Fader Controller"
        case knobController = "Knob Controller"
        case djController = "DJ Controller"
        case groovebox = "Groovebox"
        case mpeController = "MPE Controller"
        case windController = "Wind Controller"
        case guitarController = "Guitar Controller"
        case drumController = "Drum Controller"
    }

    public struct MIDIController: Identifiable, Hashable {
        public let id: UUID
        public let brand: MIDIControllerBrand
        public let model: String
        public let type: ControllerType
        public let pads: Int
        public let keys: Int
        public let faders: Int
        public let knobs: Int
        public let hasMPE: Bool
        public let hasDisplay: Bool
        public let isStandalone: Bool
        public let connectionTypes: [ConnectionType]
        public let platforms: [DevicePlatform]

        public init(
            id: UUID = UUID(),
            brand: MIDIControllerBrand,
            model: String,
            type: ControllerType,
            pads: Int = 0,
            keys: Int = 0,
            faders: Int = 0,
            knobs: Int = 0,
            hasMPE: Bool = false,
            hasDisplay: Bool = false,
            isStandalone: Bool = false,
            connectionTypes: [ConnectionType],
            platforms: [DevicePlatform]
        ) {
            self.id = id
            self.brand = brand
            self.model = model
            self.type = type
            self.pads = pads
            self.keys = keys
            self.faders = faders
            self.knobs = knobs
            self.hasMPE = hasMPE
            self.hasDisplay = hasDisplay
            self.isStandalone = isStandalone
            self.connectionTypes = connectionTypes
            self.platforms = platforms
        }
    }

    /// All supported MIDI controllers
    public let controllers: [MIDIController] = [
        // Ableton
        MIDIController(brand: .ableton, model: "Push 3", type: .padController,
                      pads: 64, knobs: 8, hasMPE: true, hasDisplay: true, isStandalone: true,
                      connectionTypes: [.usb, .bluetooth], platforms: [.macOS, .windows]),
        MIDIController(brand: .ableton, model: "Push 3 Controller", type: .padController,
                      pads: 64, knobs: 8, hasMPE: true, hasDisplay: true,
                      connectionTypes: [.usb], platforms: [.macOS, .windows]),

        // Novation Launchpad Series
        MIDIController(brand: .novation, model: "Launchpad X", type: .padController,
                      pads: 64, connectionTypes: [.usb], platforms: [.macOS, .windows, .iOS]),
        MIDIController(brand: .novation, model: "Launchpad Pro MK3", type: .padController,
                      pads: 64, hasMPE: true, connectionTypes: [.usb], platforms: [.macOS, .windows, .iOS]),
        MIDIController(brand: .novation, model: "Launchpad Mini MK3", type: .padController,
                      pads: 64, connectionTypes: [.usb], platforms: [.macOS, .windows, .iOS]),
        MIDIController(brand: .novation, model: "Launch Control XL MK2", type: .faderController,
                      faders: 8, knobs: 24, connectionTypes: [.usb], platforms: [.macOS, .windows]),

        // Novation SL MkIII
        MIDIController(brand: .novation, model: "SL MkIII 49", type: .keyboard,
                      pads: 16, keys: 49, faders: 8, knobs: 8, hasDisplay: true,
                      connectionTypes: [.usb, .midi5Pin], platforms: [.macOS, .windows]),
        MIDIController(brand: .novation, model: "SL MkIII 61", type: .keyboard,
                      pads: 16, keys: 61, faders: 8, knobs: 8, hasDisplay: true,
                      connectionTypes: [.usb, .midi5Pin], platforms: [.macOS, .windows]),

        // Native Instruments Maschine
        MIDIController(brand: .nativeInstruments, model: "Maschine MK3", type: .padController,
                      pads: 16, knobs: 8, hasDisplay: true,
                      connectionTypes: [.usb], platforms: [.macOS, .windows]),
        MIDIController(brand: .nativeInstruments, model: "Maschine+", type: .groovebox,
                      pads: 16, knobs: 8, hasDisplay: true, isStandalone: true,
                      connectionTypes: [.usb, .wifi], platforms: [.macOS, .windows]),
        MIDIController(brand: .nativeInstruments, model: "Maschine Mikro MK3", type: .padController,
                      pads: 16, hasDisplay: true, connectionTypes: [.usb], platforms: [.macOS, .windows]),

        // Native Instruments Komplete Kontrol
        MIDIController(brand: .nativeInstruments, model: "Komplete Kontrol S49 MK3", type: .keyboard,
                      keys: 49, knobs: 8, hasDisplay: true,
                      connectionTypes: [.usb], platforms: [.macOS, .windows]),
        MIDIController(brand: .nativeInstruments, model: "Komplete Kontrol S61 MK3", type: .keyboard,
                      keys: 61, knobs: 8, hasDisplay: true,
                      connectionTypes: [.usb], platforms: [.macOS, .windows]),
        MIDIController(brand: .nativeInstruments, model: "Komplete Kontrol S88 MK3", type: .keyboard,
                      keys: 88, knobs: 8, hasDisplay: true,
                      connectionTypes: [.usb], platforms: [.macOS, .windows]),
        MIDIController(brand: .nativeInstruments, model: "Komplete Kontrol M32", type: .keyboard,
                      keys: 32, knobs: 8, hasDisplay: true,
                      connectionTypes: [.usb], platforms: [.macOS, .windows]),
        MIDIController(brand: .nativeInstruments, model: "Komplete Kontrol A25", type: .keyboard,
                      keys: 25, knobs: 8, connectionTypes: [.usb], platforms: [.macOS, .windows]),
        MIDIController(brand: .nativeInstruments, model: "Komplete Kontrol A49", type: .keyboard,
                      keys: 49, knobs: 8, connectionTypes: [.usb], platforms: [.macOS, .windows]),
        MIDIController(brand: .nativeInstruments, model: "Komplete Kontrol A61", type: .keyboard,
                      keys: 61, knobs: 8, connectionTypes: [.usb], platforms: [.macOS, .windows]),

        // Akai
        MIDIController(brand: .akai, model: "MPC Live II", type: .groovebox,
                      pads: 16, knobs: 4, hasDisplay: true, isStandalone: true,
                      connectionTypes: [.usb, .midi5Pin, .wifi], platforms: [.macOS, .windows]),
        MIDIController(brand: .akai, model: "MPC One+", type: .groovebox,
                      pads: 16, knobs: 4, hasDisplay: true, isStandalone: true,
                      connectionTypes: [.usb, .midi5Pin, .wifi, .bluetooth], platforms: [.macOS, .windows]),
        MIDIController(brand: .akai, model: "MPC Key 61", type: .groovebox,
                      pads: 16, keys: 61, knobs: 4, hasDisplay: true, isStandalone: true,
                      connectionTypes: [.usb, .midi5Pin], platforms: [.macOS, .windows]),
        MIDIController(brand: .akai, model: "MPC Key 37", type: .groovebox,
                      pads: 16, keys: 37, knobs: 4, hasDisplay: true, isStandalone: true,
                      connectionTypes: [.usb, .midi5Pin], platforms: [.macOS, .windows]),
        MIDIController(brand: .akai, model: "APC64", type: .padController,
                      pads: 64, faders: 8, hasDisplay: true,
                      connectionTypes: [.usb], platforms: [.macOS, .windows]),
        MIDIController(brand: .akai, model: "APC40 MK2", type: .padController,
                      pads: 40, faders: 9, knobs: 8,
                      connectionTypes: [.usb], platforms: [.macOS, .windows]),
        MIDIController(brand: .akai, model: "MPK Mini MK3", type: .keyboard,
                      pads: 8, keys: 25, knobs: 8,
                      connectionTypes: [.usb], platforms: [.macOS, .windows, .iOS]),
        MIDIController(brand: .akai, model: "MPK Mini Play MK3", type: .keyboard,
                      pads: 8, keys: 25, knobs: 8, isStandalone: true,
                      connectionTypes: [.usb], platforms: [.macOS, .windows, .iOS]),
        MIDIController(brand: .akai, model: "MPK261", type: .keyboard,
                      pads: 16, keys: 61, faders: 8, knobs: 8,
                      connectionTypes: [.usb], platforms: [.macOS, .windows]),
        MIDIController(brand: .akai, model: "MPD218", type: .padController,
                      pads: 16, knobs: 6,
                      connectionTypes: [.usb], platforms: [.macOS, .windows, .iOS]),
        MIDIController(brand: .akai, model: "MPD226", type: .padController,
                      pads: 16, faders: 4, knobs: 4,
                      connectionTypes: [.usb], platforms: [.macOS, .windows]),
        MIDIController(brand: .akai, model: "MIDIMIX", type: .faderController,
                      faders: 9, knobs: 24,
                      connectionTypes: [.usb], platforms: [.macOS, .windows]),

        // Arturia
        MIDIController(brand: .arturia, model: "KeyLab Essential 49 MK3", type: .keyboard,
                      pads: 8, keys: 49, faders: 9, knobs: 9, hasDisplay: true,
                      connectionTypes: [.usb], platforms: [.macOS, .windows, .iOS]),
        MIDIController(brand: .arturia, model: "KeyLab Essential 61 MK3", type: .keyboard,
                      pads: 8, keys: 61, faders: 9, knobs: 9, hasDisplay: true,
                      connectionTypes: [.usb], platforms: [.macOS, .windows, .iOS]),
        MIDIController(brand: .arturia, model: "KeyLab Essential 88 MK3", type: .keyboard,
                      pads: 8, keys: 88, faders: 9, knobs: 9, hasDisplay: true,
                      connectionTypes: [.usb], platforms: [.macOS, .windows]),
        MIDIController(brand: .arturia, model: "KeyLab 49 MK2", type: .keyboard,
                      pads: 16, keys: 49, faders: 9, knobs: 9, hasDisplay: true,
                      connectionTypes: [.usb], platforms: [.macOS, .windows]),
        MIDIController(brand: .arturia, model: "KeyLab 61 MK2", type: .keyboard,
                      pads: 16, keys: 61, faders: 9, knobs: 9, hasDisplay: true,
                      connectionTypes: [.usb], platforms: [.macOS, .windows]),
        MIDIController(brand: .arturia, model: "KeyLab 88 MK2", type: .keyboard,
                      pads: 16, keys: 88, faders: 9, knobs: 9, hasDisplay: true,
                      connectionTypes: [.usb], platforms: [.macOS, .windows]),
        MIDIController(brand: .arturia, model: "MiniLab 3", type: .keyboard,
                      pads: 8, keys: 25, knobs: 8,
                      connectionTypes: [.usb], platforms: [.macOS, .windows, .iOS]),
        MIDIController(brand: .arturia, model: "BeatStep Pro", type: .padController,
                      pads: 16, knobs: 16,
                      connectionTypes: [.usb, .midi5Pin], platforms: [.macOS, .windows]),

        // Roland
        MIDIController(brand: .roland, model: "A-88 MKII", type: .keyboard,
                      keys: 88, connectionTypes: [.usb, .midi5Pin, .bluetooth],
                      platforms: [.macOS, .windows, .iOS]),
        MIDIController(brand: .roland, model: "A-49", type: .keyboard,
                      keys: 49, connectionTypes: [.usb],
                      platforms: [.macOS, .windows, .iOS]),
        MIDIController(brand: .roland, model: "SPD-SX PRO", type: .drumController,
                      pads: 9, hasDisplay: true, isStandalone: true,
                      connectionTypes: [.usb, .midi5Pin], platforms: [.macOS, .windows]),
        MIDIController(brand: .roland, model: "TD-27KV2", type: .drumController,
                      pads: 18, hasDisplay: true, isStandalone: true,
                      connectionTypes: [.usb, .midi5Pin], platforms: [.macOS, .windows]),

        // Korg
        MIDIController(brand: .korg, model: "nanoKEY2", type: .keyboard,
                      keys: 25, connectionTypes: [.usb], platforms: [.macOS, .windows, .iOS]),
        MIDIController(brand: .korg, model: "nanoKONTROL2", type: .faderController,
                      faders: 8, knobs: 8, connectionTypes: [.usb], platforms: [.macOS, .windows, .iOS]),
        MIDIController(brand: .korg, model: "nanoPAD2", type: .padController,
                      pads: 16, connectionTypes: [.usb], platforms: [.macOS, .windows, .iOS]),
        MIDIController(brand: .korg, model: "Keystage 49", type: .keyboard,
                      pads: 8, keys: 49, faders: 4, knobs: 4, hasDisplay: true,
                      connectionTypes: [.usb, .bluetooth], platforms: [.macOS, .windows, .iOS]),
        MIDIController(brand: .korg, model: "Keystage 61", type: .keyboard,
                      pads: 8, keys: 61, faders: 4, knobs: 4, hasDisplay: true,
                      connectionTypes: [.usb, .bluetooth], platforms: [.macOS, .windows, .iOS]),

        // MPE Controllers
        MIDIController(brand: .roli, model: "Seaboard RISE 2", type: .mpeController,
                      keys: 49, hasMPE: true,
                      connectionTypes: [.usb, .bluetooth], platforms: [.macOS, .windows, .iOS]),
        MIDIController(brand: .roli, model: "Lumi Keys Studio Edition", type: .mpeController,
                      keys: 24, hasMPE: true,
                      connectionTypes: [.usb, .bluetooth], platforms: [.macOS, .windows, .iOS]),
        MIDIController(brand: .sensel, model: "Morph", type: .mpeController,
                      hasMPE: true, connectionTypes: [.usb, .bluetooth],
                      platforms: [.macOS, .windows, .iOS]),
        MIDIController(brand: .expressiveE, model: "Osmose", type: .mpeController,
                      keys: 49, hasMPE: true, isStandalone: true,
                      connectionTypes: [.usb, .midi5Pin], platforms: [.macOS, .windows]),
        MIDIController(brand: .keith, model: "K-Board Pro 4", type: .mpeController,
                      keys: 48, hasMPE: true,
                      connectionTypes: [.usb], platforms: [.macOS, .windows, .iOS]),
        MIDIController(brand: .keith, model: "QuNeo", type: .padController,
                      pads: 16, faders: 9, hasMPE: true,
                      connectionTypes: [.usb], platforms: [.macOS, .windows, .iOS]),

        // Wind Controller
        MIDIController(brand: .roland, model: "Aerophone Pro", type: .windController,
                      hasDisplay: true, isStandalone: true,
                      connectionTypes: [.usb, .bluetooth], platforms: [.macOS, .windows, .iOS]),
        MIDIController(brand: .akai, model: "EWI Solo", type: .windController,
                      isStandalone: true, connectionTypes: [.usb, .bluetooth],
                      platforms: [.macOS, .windows, .iOS]),
    ]
}
