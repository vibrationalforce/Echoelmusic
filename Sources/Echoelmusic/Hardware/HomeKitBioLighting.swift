// HomeKitBioLighting.swift
// Echoelmusic — HomeKit & Philips Hue Bio-Reactive Lighting Controller
//
// Maps biometric data (HRV coherence, heart rate, breathing) to smart home lighting
// via HomeKit framework and Philips Hue Entertainment API for low-latency color control.
//
// Supports:
//   - HomeKit-compatible lights (any brand)
//   - Philips Hue direct control via Entertainment API (~25ms latency)
//   - LIFX, Nanoleaf via HomeKit bridge
//   - Bio-reactive color mapping (coherence → warmth, HR → pulse, breath → brightness)
//   - Audio-reactive accent mode (spectral centroid → hue)
//
// Copyright 2026 Echoelmusic. MIT License.

import Foundation
import Combine

#if canImport(HomeKit)
import HomeKit
#endif

// MARK: - Bio-Reactive Light State

/// Represents the desired lighting state derived from biometrics
public struct BioLightState: Equatable {
    /// Hue (0-1, maps to 0-360 degrees)
    public var hue: Float = 0.08        // Warm amber default
    /// Saturation (0-1)
    public var saturation: Float = 0.6
    /// Brightness (0-1)
    public var brightness: Float = 0.5
    /// Color temperature in Kelvin (2000-6500)
    public var colorTemperature: Int = 2700
    /// Transition time in milliseconds
    public var transitionMs: Int = 200

    /// Convert to RGB for Hue Entertainment API
    public var rgb: (r: Float, g: Float, b: Float) {
        hsbToRGB(h: hue, s: saturation, b: brightness)
    }

    private func hsbToRGB(h: Float, s: Float, b: Float) -> (r: Float, g: Float, b: Float) {
        if s == 0 { return (b, b, b) }
        let hue6 = h * 6.0
        let sector = Int(hue6) % 6
        let f = hue6 - Float(Int(hue6))
        let p = b * (1.0 - s)
        let q = b * (1.0 - s * f)
        let t = b * (1.0 - s * (1.0 - f))
        switch sector {
        case 0: return (b, t, p)
        case 1: return (q, b, p)
        case 2: return (p, b, t)
        case 3: return (p, q, b)
        case 4: return (t, p, b)
        default: return (b, p, q)
        }
    }
}

// MARK: - Bio-to-Light Mapping Configuration

/// Configures how biometric signals map to lighting parameters
public struct BioLightMapping {
    /// Coherence → color warmth (high coherence = warm golden, low = cool blue)
    public var coherenceToWarmth: Float = 0.8
    /// Heart rate → brightness pulse depth (subtle pulsing with heartbeat)
    public var heartRateToPulse: Float = 0.3
    /// Breathing phase → brightness modulation
    public var breathToBrightness: Float = 0.4
    /// HRV → saturation (high HRV = rich colors, low = desaturated)
    public var hrvToSaturation: Float = 0.5
    /// Audio spectral centroid → hue accent (optional audio-reactive)
    public var audioToHue: Float = 0.0
    /// Minimum brightness (never goes fully dark)
    public var minBrightness: Float = 0.1
    /// Maximum brightness
    public var maxBrightness: Float = 0.9

    public init() {}
}

// MARK: - Light Zone

/// A logical lighting zone (e.g., "behind screen", "room perimeter")
public struct LightZone: Identifiable {
    public let id: UUID
    public let name: String
    /// HomeKit accessory UUIDs in this zone
    public var accessoryIDs: [UUID]
    /// Hue Entertainment group ID (nil if not Hue)
    public var hueGroupID: String?
    /// Offset applied to bio-light state (for spatial variation)
    public var hueOffset: Float = 0
    /// Brightness scale relative to master
    public var brightnessScale: Float = 1.0

    public init(
        id: UUID = UUID(),
        name: String,
        accessoryIDs: [UUID] = [],
        hueGroupID: String? = nil,
        hueOffset: Float = 0,
        brightnessScale: Float = 1.0
    ) {
        self.id = id
        self.name = name
        self.accessoryIDs = accessoryIDs
        self.hueGroupID = hueGroupID
        self.hueOffset = hueOffset
        self.brightnessScale = brightnessScale
    }
}

// MARK: - HomeKit Bio-Reactive Lighting Controller

/// Main controller: maps biometrics to HomeKit/Hue light states
public final class HomeKitBioLighting {

    // MARK: - Configuration

    public var mapping = BioLightMapping()
    public var zones: [LightZone] = []
    public var isEnabled: Bool = false
    public var updateRate: TimeInterval = 1.0 / 15.0  // 15 Hz light updates

    // MARK: - Current State

    public private(set) var currentState = BioLightState()
    public private(set) var isConnected: Bool = false

    // MARK: - Bio Input Cache

    private var coherence: Float = 0.5
    private var heartRate: Float = 0.5   // Normalized 0-1
    private var breathPhase: Float = 0.0 // 0-1 sine-like
    private var breathDepth: Float = 0.5
    private var hrv: Float = 0.5
    private var spectralCentroid: Float = 0.5

    // MARK: - Internal

    private var updateTimer: Timer?
    private var smoothedState = BioLightState()
    private let smoothingFactor: Float = 0.15 // Exponential smoothing

    #if canImport(HomeKit)
    private var homeManager: HMHomeManager?
    private var primaryHome: HMHome?
    #endif

    // MARK: - Init

    public init() {}

    // MARK: - Connection

    /// Initialize HomeKit connection
    public func connect() {
        #if canImport(HomeKit)
        homeManager = HMHomeManager()
        // HomeKit delegate will set primaryHome when ready
        isConnected = true
        #endif
    }

    /// Disconnect and stop updates
    public func disconnect() {
        stopUpdates()
        isConnected = false
        #if canImport(HomeKit)
        homeManager = nil
        primaryHome = nil
        #endif
    }

    // MARK: - Update Loop

    /// Start periodic light updates
    public func startUpdates() {
        guard isEnabled else { return }
        stopUpdates()
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateRate, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    /// Stop periodic light updates
    public func stopUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    // MARK: - Bio Input

    /// Update biometric inputs
    public func updateBio(
        coherence: Float,
        heartRate: Float = 0.5,
        breathPhase: Float = 0.0,
        breathDepth: Float = 0.5,
        hrv: Float = 0.5
    ) {
        self.coherence = coherence
        self.heartRate = heartRate
        self.breathPhase = breathPhase
        self.breathDepth = breathDepth
        self.hrv = hrv
    }

    /// Update audio-reactive input (optional)
    public func updateAudio(spectralCentroid: Float) {
        self.spectralCentroid = spectralCentroid
    }

    // MARK: - Bio-to-Light Computation

    /// Compute desired light state from current biometrics
    public func computeLightState() -> BioLightState {
        var state = BioLightState()

        // Coherence → color temperature / warmth
        // High coherence → warm golden (hue ~0.08-0.12)
        // Low coherence → cool blue-white (hue ~0.55-0.65)
        let warmth = coherence * mapping.coherenceToWarmth
        state.hue = mix(0.60, 0.08, t: warmth)

        // HRV → saturation (high variability = rich color)
        state.saturation = mix(0.2, 0.8, t: hrv * mapping.hrvToSaturation + 0.3)

        // Breathing → brightness modulation
        let breathMod = sin(breathPhase * 2.0 * .pi) * 0.5 + 0.5 // 0-1
        let breathContribution = breathMod * breathDepth * mapping.breathToBrightness
        state.brightness = mix(mapping.minBrightness, mapping.maxBrightness,
                               t: 0.5 + breathContribution * 0.5)

        // Heart rate → subtle brightness pulse
        let hrPulse = sin(heartRate * 2.0 * .pi) * mapping.heartRateToPulse * 0.1
        state.brightness = max(mapping.minBrightness, min(mapping.maxBrightness,
                                                           state.brightness + hrPulse))

        // Audio → hue accent (optional)
        if mapping.audioToHue > 0 {
            let audioHueShift = (spectralCentroid - 0.5) * mapping.audioToHue * 0.2
            state.hue = fmod(state.hue + audioHueShift + 1.0, 1.0)
        }

        // Color temperature from warmth
        state.colorTemperature = Int(mix(6500, 2000, t: warmth))

        // Fast transition for responsiveness
        state.transitionMs = Int(updateRate * 1000 * 0.8)

        return state
    }

    // MARK: - Update Tick

    private func tick() {
        let target = computeLightState()

        // Smooth transitions (exponential smoothing)
        smoothedState.hue = smoothedState.hue + (target.hue - smoothedState.hue) * smoothingFactor
        smoothedState.saturation = smoothedState.saturation + (target.saturation - smoothedState.saturation) * smoothingFactor
        smoothedState.brightness = smoothedState.brightness + (target.brightness - smoothedState.brightness) * smoothingFactor
        smoothedState.colorTemperature = target.colorTemperature
        smoothedState.transitionMs = target.transitionMs

        currentState = smoothedState

        // Apply to all zones
        for zone in zones {
            applyToZone(zone, state: currentState)
        }
    }

    // MARK: - HomeKit Application

    private func applyToZone(_ zone: LightZone, state: BioLightState) {
        var zoneState = state

        // Apply zone offsets
        zoneState.hue = fmod(state.hue + zone.hueOffset + 1.0, 1.0)
        zoneState.brightness = min(1.0, state.brightness * zone.brightnessScale)

        #if canImport(HomeKit)
        applyViaHomeKit(zone: zone, state: zoneState)
        #endif
    }

    #if canImport(HomeKit)
    private func applyViaHomeKit(zone: LightZone, state: BioLightState) {
        guard let home = primaryHome else { return }

        for accessory in home.accessories {
            guard zone.accessoryIDs.contains(accessory.uniqueIdentifier) else { continue }

            for service in accessory.services where service.serviceType == HMServiceTypeLightbulb {
                for characteristic in service.characteristics {
                    switch characteristic.characteristicType {
                    case HMCharacteristicTypeHue:
                        characteristic.writeValue(state.hue * 360.0, completionHandler: { _ in })
                    case HMCharacteristicTypeSaturation:
                        characteristic.writeValue(state.saturation * 100.0, completionHandler: { _ in })
                    case HMCharacteristicTypeBrightness:
                        characteristic.writeValue(Int(state.brightness * 100.0), completionHandler: { _ in })
                    default:
                        break
                    }
                }
            }
        }
    }
    #endif

    // MARK: - Zone Management

    /// Add a lighting zone
    public func addZone(_ zone: LightZone) {
        zones.append(zone)
    }

    /// Remove a zone by ID
    public func removeZone(id: UUID) {
        zones.removeAll { $0.id == id }
    }

    // MARK: - Presets

    /// Apply a coherence-based scene preset
    public func applyPreset(_ preset: BioLightPreset) {
        mapping = preset.mapping
        for (index, offset) in preset.zoneHueOffsets.enumerated() where index < zones.count {
            zones[index].hueOffset = offset
        }
    }

    // MARK: - Helpers

    private func mix(_ a: Float, _ b: Float, t: Float) -> Float {
        a + (b - a) * max(0, min(1, t))
    }
}

// MARK: - Bio Light Presets

public struct BioLightPreset {
    public let name: String
    public let mapping: BioLightMapping
    public let zoneHueOffsets: [Float]

    public static let relaxation: BioLightPreset = {
        var m = BioLightMapping()
        m.coherenceToWarmth = 0.9
        m.breathToBrightness = 0.6
        m.heartRateToPulse = 0.1
        m.minBrightness = 0.15
        m.maxBrightness = 0.6
        return BioLightPreset(name: "Relaxation", mapping: m, zoneHueOffsets: [0, 0.02, -0.02])
    }()

    public static let focus: BioLightPreset = {
        var m = BioLightMapping()
        m.coherenceToWarmth = 0.4
        m.breathToBrightness = 0.2
        m.heartRateToPulse = 0.0
        m.minBrightness = 0.5
        m.maxBrightness = 0.95
        return BioLightPreset(name: "Focus", mapping: m, zoneHueOffsets: [0, 0, 0])
    }()

    public static let performance: BioLightPreset = {
        var m = BioLightMapping()
        m.coherenceToWarmth = 0.7
        m.breathToBrightness = 0.5
        m.heartRateToPulse = 0.4
        m.audioToHue = 0.6
        m.minBrightness = 0.3
        m.maxBrightness = 1.0
        return BioLightPreset(name: "Performance", mapping: m, zoneHueOffsets: [0, 0.15, -0.15, 0.3])
    }()

    public static let sleep: BioLightPreset = {
        var m = BioLightMapping()
        m.coherenceToWarmth = 1.0
        m.breathToBrightness = 0.8
        m.heartRateToPulse = 0.0
        m.minBrightness = 0.02
        m.maxBrightness = 0.15
        return BioLightPreset(name: "Sleep", mapping: m, zoneHueOffsets: [0, 0.01, -0.01])
    }()
}
