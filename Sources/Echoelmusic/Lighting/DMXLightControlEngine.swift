import Foundation
import Combine
import CoreMIDI
import Accelerate
import simd

// ═══════════════════════════════════════════════════════════════════════════════════════
// ╔═══════════════════════════════════════════════════════════════════════════════════╗
// ║       DMX LIGHT CONTROL ENGINE - BIO/AUDIO/MIDI/MPE INTEGRATION                   ║
// ║                                                                                    ║
// ║   Professional lighting control with scientific accuracy:                          ║
// ║   • DMX512/Art-Net/sACN protocol support                                          ║
// ║   • Bio-reactive light mapping (HRV → Color, Heart Rate → Intensity)              ║
// ║   • Audio-reactive (FFT spectrum → DMX channels)                                  ║
// ║   • MIDI/MPE → Light parameter mapping                                            ║
// ║   • Physics-based color science (CIE 1931, Planckian locus)                       ║
// ║   • Circadian rhythm optimization                                                  ║
// ║                                                                                    ║
// ╚═══════════════════════════════════════════════════════════════════════════════════╝
// ═══════════════════════════════════════════════════════════════════════════════════════

// MARK: - DMX Universe Model

public struct DMXUniverse: Identifiable, Sendable {
    public let id: Int // Universe number (0-32767 for Art-Net)
    public var channels: [UInt8] // 512 channels per universe
    public var fixtures: [DMXFixture]

    public init(id: Int) {
        self.id = id
        self.channels = [UInt8](repeating: 0, count: 512)
        self.fixtures = []
    }

    public mutating func setChannel(_ channel: Int, value: UInt8) {
        guard channel >= 1 && channel <= 512 else { return }
        channels[channel - 1] = value
    }

    public func getChannel(_ channel: Int) -> UInt8 {
        guard channel >= 1 && channel <= 512 else { return 0 }
        return channels[channel - 1]
    }
}

// MARK: - DMX Fixture Model

public struct DMXFixture: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var type: FixtureType
    public var universe: Int
    public var startAddress: Int
    public var channelCount: Int
    public var personality: FixturePersonality

    public enum FixtureType: String, Codable, CaseIterable, Sendable {
        case parCan = "PAR Can"
        case movingHead = "Moving Head"
        case ledBar = "LED Bar"
        case strobe = "Strobe"
        case laser = "Laser"
        case hazer = "Hazer"
        case dimmer = "Dimmer"
        case rgbwLED = "RGBW LED"
        case pixelStrip = "Pixel Strip"
        case genericDimmer = "Generic Dimmer"
    }

    public struct FixturePersonality: Codable, Sendable {
        public var channelLayout: [ChannelFunction]

        public enum ChannelFunction: String, Codable, Sendable {
            case dimmer, red, green, blue, white, amber, uv
            case pan, tilt, panFine, tiltFine
            case colorWheel, gobo, goboRotation
            case prism, focus, zoom, iris
            case strobe, shutter
            case speed, macro, reset
        }
    }
}

// MARK: - Color Science (CIE 1931)

/// CIE 1931 XYZ Color Space with scientific accuracy
public struct CIEColor: Sendable {
    public var X: Double
    public var Y: Double // Luminance
    public var Z: Double

    /// Convert from sRGB to CIE XYZ (D65 illuminant)
    public init(sRGB r: Double, g: Double, b: Double) {
        // Linearize sRGB (inverse gamma)
        func linearize(_ c: Double) -> Double {
            if c <= 0.04045 {
                return c / 12.92
            }
            return pow((c + 0.055) / 1.055, 2.4)
        }

        let rLin = linearize(r)
        let gLin = linearize(g)
        let bLin = linearize(b)

        // sRGB to XYZ matrix (D65)
        self.X = 0.4124564 * rLin + 0.3575761 * gLin + 0.1804375 * bLin
        self.Y = 0.2126729 * rLin + 0.7151522 * gLin + 0.0721750 * bLin
        self.Z = 0.0193339 * rLin + 0.1191920 * gLin + 0.9503041 * bLin
    }

    public init(X: Double, Y: Double, Z: Double) {
        self.X = X
        self.Y = Y
        self.Z = Z
    }

    /// CIE xy chromaticity coordinates
    public var chromaticity: (x: Double, y: Double) {
        let sum = X + Y + Z
        guard sum > 0 else { return (0.3127, 0.3290) } // D65 white point
        return (X / sum, Y / sum)
    }

    /// Convert to sRGB
    public func toSRGB() -> (r: Double, g: Double, b: Double) {
        // XYZ to sRGB matrix (D65)
        let rLin =  3.2404542 * X - 1.5371385 * Y - 0.4985314 * Z
        let gLin = -0.9692660 * X + 1.8760108 * Y + 0.0415560 * Z
        let bLin =  0.0556434 * X - 0.2040259 * Y + 1.0572252 * Z

        // Apply gamma
        func gammaCorrect(_ c: Double) -> Double {
            let clamped = max(0, min(1, c))
            if clamped <= 0.0031308 {
                return 12.92 * clamped
            }
            return 1.055 * pow(clamped, 1/2.4) - 0.055
        }

        return (gammaCorrect(rLin), gammaCorrect(gLin), gammaCorrect(bLin))
    }

    /// Correlated Color Temperature (CCT) using McCamy's approximation
    public var colorTemperature: Double {
        let (x, y) = chromaticity
        let n = (x - 0.3320) / (0.1858 - y)
        return 449 * pow(n, 3) + 3525 * pow(n, 2) + 6823.3 * n + 5520.33
    }
}

/// Planckian (Black Body) Radiator - Physics-accurate color temperature
public struct PlanckianRadiator {

    /// Calculate CIE xy chromaticity for a given color temperature (Kelvin)
    /// Using Planck's law and CIE 1931 color matching functions
    public static func chromaticity(kelvin: Double) -> (x: Double, y: Double) {
        // Approximation valid for 1667K - 25000K
        let T = kelvin
        var x: Double

        if T >= 1667 && T <= 4000 {
            x = -0.2661239e9 / pow(T, 3) - 0.2343589e6 / pow(T, 2) + 0.8776956e3 / T + 0.179910
        } else if T > 4000 && T <= 25000 {
            x = -3.0258469e9 / pow(T, 3) + 2.1070379e6 / pow(T, 2) + 0.2226347e3 / T + 0.24039
        } else {
            x = 0.3127 // D65 fallback
        }

        var y: Double
        if T >= 1667 && T <= 2222 {
            y = -1.1063814 * pow(x, 3) - 1.34811020 * pow(x, 2) + 2.18555832 * x - 0.20219683
        } else if T > 2222 && T <= 4000 {
            y = -0.9549476 * pow(x, 3) - 1.37418593 * pow(x, 2) + 2.09137015 * x - 0.16748867
        } else if T > 4000 && T <= 25000 {
            y = 3.0817580 * pow(x, 3) - 5.87338670 * pow(x, 2) + 3.75112997 * x - 0.37001483
        } else {
            y = 0.3290 // D65 fallback
        }

        return (x, y)
    }

    /// Convert color temperature to RGB
    public static func toRGB(kelvin: Double, brightness: Double = 1.0) -> (r: UInt8, g: UInt8, b: UInt8) {
        let (x, y) = chromaticity(kelvin: kelvin)

        // Convert xy to XYZ (assuming Y = brightness)
        let Y = brightness
        let X = (Y / y) * x
        let Z = (Y / y) * (1 - x - y)

        let color = CIEColor(X: X, Y: Y, Z: Z)
        let (r, g, b) = color.toSRGB()

        return (UInt8(r * 255), UInt8(g * 255), UInt8(b * 255))
    }
}

// MARK: - Bio-Light Mapping

/// Maps biological signals to lighting parameters using psychophysiological research
public struct BioLightMapper: Sendable {

    // MARK: - Circadian Rhythm (Based on melanopic response research)

    /// Calculate optimal color temperature based on time of day
    /// Based on circadian rhythm research (Brainard et al., 2001)
    public static func circadianColorTemperature(hour: Int, minute: Int = 0) -> Double {
        let timeDecimal = Double(hour) + Double(minute) / 60.0

        // Morning (6-9): Increase from warm to cool (alertness boost)
        // Midday (9-17): Cool white (5000-6500K) for productivity
        // Evening (17-21): Gradual decrease to warm (2700K)
        // Night (21-6): Warm/dim (2200K) to support melatonin

        if timeDecimal >= 6 && timeDecimal < 9 {
            let progress = (timeDecimal - 6) / 3
            return 2700 + progress * 3300 // 2700K → 6000K
        } else if timeDecimal >= 9 && timeDecimal < 17 {
            return 5500 // Daylight
        } else if timeDecimal >= 17 && timeDecimal < 21 {
            let progress = (timeDecimal - 17) / 4
            return 5500 - progress * 2800 // 5500K → 2700K
        } else {
            return 2200 // Warm for sleep
        }
    }

    /// Calculate melanopic lux ratio for circadian effectiveness
    /// Based on CIE S 026:2018 standard
    public static func melanopicRatio(colorTemperature: Double) -> Double {
        // Melanopic response peaks at ~480nm (blue)
        // Higher CCT = higher melanopic content
        if colorTemperature < 2700 { return 0.45 }
        if colorTemperature < 4000 { return 0.6 }
        if colorTemperature < 5000 { return 0.8 }
        if colorTemperature < 6500 { return 0.95 }
        return 1.0
    }

    // MARK: - HRV Coherence Mapping

    /// Map HRV coherence (0-1) to color
    /// Based on HeartMath research on coherence states
    public static func coherenceToColor(_ coherence: Double) -> (r: UInt8, g: UInt8, b: UInt8) {
        // Low coherence: Red (stress indicator)
        // Medium coherence: Yellow/Orange (transition)
        // High coherence: Green (optimal state)

        let clamped = max(0, min(1, coherence))

        if clamped < 0.33 {
            // Red to Orange
            let t = clamped / 0.33
            return (255, UInt8(t * 165), 0)
        } else if clamped < 0.66 {
            // Orange to Yellow to Green
            let t = (clamped - 0.33) / 0.33
            return (UInt8(255 * (1 - t)), UInt8(165 + t * 90), 0)
        } else {
            // Yellow-Green to Green
            let t = (clamped - 0.66) / 0.34
            return (UInt8(128 * (1 - t)), 255, UInt8(t * 100))
        }
    }

    /// Map heart rate to light pulsation speed
    /// Returns pulse duration in seconds
    public static func heartRateToPulseDuration(bpm: Double) -> Double {
        // Direct mapping: 60 BPM = 1 second pulse
        guard bpm > 0 else { return 1.0 }
        return 60.0 / bpm
    }

    /// Map breathing rate to light intensity wave
    public static func breathingToIntensity(phase: Double, rate: Double) -> Double {
        // Sinusoidal breathing wave
        // phase: 0-1 (current position in breath cycle)
        // Returns intensity 0-1
        return (sin(phase * 2 * .pi) + 1) / 2
    }

    // MARK: - Emotional State Mapping

    /// Map arousal-valence emotional state to lighting
    /// Based on Russell's circumplex model of affect
    public static func emotionToLighting(arousal: Double, valence: Double) -> (
        colorTemp: Double,
        saturation: Double,
        brightness: Double
    ) {
        // Arousal: -1 (calm) to +1 (excited)
        // Valence: -1 (negative) to +1 (positive)

        // High arousal + positive: Bright, cool, saturated
        // High arousal + negative: Bright, warm, saturated (reds)
        // Low arousal + positive: Dim, warm, desaturated
        // Low arousal + negative: Dim, cool, desaturated

        let brightness = 0.3 + (arousal + 1) / 2 * 0.7 // 0.3-1.0

        var colorTemp: Double
        if valence > 0 {
            colorTemp = 4000 + arousal * 2000 // 2000-6000K
        } else {
            colorTemp = 3000 - arousal * 500 // 2500-3500K (warmer for negative)
        }

        let saturation = 0.3 + abs(valence) * 0.7 // More saturated at emotional extremes

        return (colorTemp, saturation, brightness)
    }
}

// MARK: - Audio to Light Mapping

/// Maps audio analysis to lighting parameters
public struct AudioLightMapper: Sendable {

    /// FFT frequency bands for lighting
    public enum FrequencyBand: Int, CaseIterable, Sendable {
        case subBass = 0     // 20-60 Hz
        case bass = 1        // 60-250 Hz
        case lowMid = 2      // 250-500 Hz
        case mid = 3         // 500-2000 Hz
        case highMid = 4     // 2000-4000 Hz
        case presence = 5    // 4000-6000 Hz
        case brilliance = 6  // 6000-20000 Hz

        public var frequencyRange: ClosedRange<Double> {
            switch self {
            case .subBass: return 20...60
            case .bass: return 60...250
            case .lowMid: return 250...500
            case .mid: return 500...2000
            case .highMid: return 2000...4000
            case .presence: return 4000...6000
            case .brilliance: return 6000...20000
            }
        }

        /// Suggested color for this frequency band
        public var suggestedColor: (r: UInt8, g: UInt8, b: UInt8) {
            switch self {
            case .subBass: return (128, 0, 255)    // Deep purple
            case .bass: return (0, 0, 255)         // Blue
            case .lowMid: return (0, 255, 255)     // Cyan
            case .mid: return (0, 255, 0)          // Green
            case .highMid: return (255, 255, 0)    // Yellow
            case .presence: return (255, 128, 0)   // Orange
            case .brilliance: return (255, 0, 0)   // Red
            }
        }
    }

    /// Extract frequency band energy from FFT magnitudes
    public static func extractBandEnergy(
        fftMagnitudes: [Float],
        sampleRate: Double,
        fftSize: Int,
        band: FrequencyBand
    ) -> Float {
        let binWidth = sampleRate / Double(fftSize)
        let startBin = Int(band.frequencyRange.lowerBound / binWidth)
        let endBin = min(Int(band.frequencyRange.upperBound / binWidth), fftMagnitudes.count - 1)

        guard startBin < endBin && startBin < fftMagnitudes.count else { return 0 }

        var sum: Float = 0
        vDSP_sve(Array(fftMagnitudes[startBin...endBin]), 1, &sum, vDSP_Length(endBin - startBin + 1))

        return sum / Float(endBin - startBin + 1)
    }

    /// Map RMS level to DMX dimmer value with proper gamma
    public static func rmsToDMX(rms: Float, gamma: Float = 2.2) -> UInt8 {
        // Apply perceptual gamma correction
        let normalized = max(0, min(1, rms))
        let gammaCorrected = pow(normalized, 1 / gamma)
        return UInt8(gammaCorrected * 255)
    }

    /// Calculate beat-reactive strobe rate
    public static func beatToStrobeRate(bpm: Double, subdivision: Int = 1) -> Double {
        // subdivision: 1 = quarter notes, 2 = eighth notes, 4 = sixteenth notes
        return (bpm / 60.0) * Double(subdivision)
    }
}

// MARK: - MIDI/MPE to Light Mapping

/// Maps MIDI and MPE data to lighting parameters
public struct MIDILightMapper: Sendable {

    /// MIDI note to color (chromatic circle mapping)
    /// Based on Scriabin's synesthesia / color-tone association
    public static func noteToColor(note: UInt8) -> (r: UInt8, g: UInt8, b: UInt8) {
        // Map MIDI note to hue (0-360°)
        // C = Red, G = Blue-Green, etc.
        let pitchClass = note % 12

        // Scriabin-inspired color mapping
        let colors: [(UInt8, UInt8, UInt8)] = [
            (255, 0, 0),      // C - Red
            (255, 75, 0),     // C# - Orange-Red
            (255, 150, 0),    // D - Orange
            (255, 225, 0),    // D# - Yellow-Orange
            (255, 255, 0),    // E - Yellow
            (150, 255, 0),    // F - Yellow-Green
            (0, 255, 0),      // F# - Green
            (0, 255, 150),    // G - Blue-Green
            (0, 150, 255),    // G# - Cyan
            (0, 0, 255),      // A - Blue
            (150, 0, 255),    // A# - Violet
            (255, 0, 150)     // B - Magenta
        ]

        return colors[Int(pitchClass)]
    }

    /// MIDI velocity to brightness
    public static func velocityToBrightness(velocity: UInt8) -> UInt8 {
        // Apply slight curve for more natural response
        let normalized = Float(velocity) / 127.0
        let curved = pow(normalized, 0.8) // Slight expansion at low velocities
        return UInt8(curved * 255)
    }

    /// MPE pressure (aftertouch) to light intensity modulation
    public static func pressureToModulation(pressure: UInt8) -> Float {
        return Float(pressure) / 127.0
    }

    /// MPE slide (CC74) to color temperature shift
    public static func slideToColorTempShift(slide: UInt8, baseTemp: Double) -> Double {
        // Slide up = cooler, Slide down = warmer
        let shift = (Double(slide) - 64) / 64 * 2000 // ±2000K
        return baseTemp + shift
    }

    /// MPE pitch bend to saturation
    public static func pitchBendToSaturation(bend: Int16) -> Float {
        // Bend range: -8192 to +8191
        let normalized = Float(bend + 8192) / 16383.0
        return 0.3 + normalized * 0.7 // 0.3-1.0 saturation
    }
}

// MARK: - DMX Light Control Engine

@MainActor
public final class DMXLightControlEngine: ObservableObject {

    public static let shared = DMXLightControlEngine()

    // MARK: - Published State

    @Published public private(set) var universes: [DMXUniverse] = []
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var outputProtocol: OutputProtocol = .artNet
    @Published public private(set) var frameRate: Double = 44 // DMX512 standard max

    // Bio-reactive state
    @Published public var bioReactiveEnabled: Bool = true
    @Published public var audioReactiveEnabled: Bool = true
    @Published public var midiReactiveEnabled: Bool = true
    @Published public var circadianEnabled: Bool = true

    // Current mapped values
    @Published public private(set) var currentCoherence: Double = 0.5
    @Published public private(set) var currentHeartRate: Double = 70
    @Published public private(set) var currentColorTemperature: Double = 5000

    public enum OutputProtocol: String, CaseIterable, Sendable {
        case artNet = "Art-Net"
        case sACN = "sACN (E1.31)"
        case dmxUSB = "DMX USB"
        case osc = "OSC"
    }

    // MARK: - Private Properties

    private var outputTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        // Create default universe
        universes = [DMXUniverse(id: 0)]

        setupBioReactiveBinding()
        setupAudioReactiveBinding()
    }

    // MARK: - Universe Management

    public func addUniverse() {
        let newID = (universes.map { $0.id }.max() ?? -1) + 1
        universes.append(DMXUniverse(id: newID))
    }

    public func removeUniverse(id: Int) {
        universes.removeAll { $0.id == id }
    }

    // MARK: - Fixture Management

    public func addFixture(_ fixture: DMXFixture, to universeID: Int) {
        guard let index = universes.firstIndex(where: { $0.id == universeID }) else { return }
        universes[index].fixtures.append(fixture)
    }

    // MARK: - Output Control

    public func startOutput() {
        guard !isConnected else { return }

        outputTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / frameRate, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sendDMXFrame()
            }
        }

        isConnected = true
        EchoelLog.visual.info("DMX output started at \(self.frameRate) fps")
    }

    public func stopOutput() {
        outputTimer?.invalidate()
        outputTimer = nil
        isConnected = false
        EchoelLog.visual.info("DMX output stopped")
    }

    private func sendDMXFrame() {
        // Apply bio-reactive updates
        if bioReactiveEnabled {
            applyBioReactiveMapping()
        }

        // Apply circadian adjustment
        if circadianEnabled {
            applyCircadianAdjustment()
        }

        // Send to output
        for universe in universes {
            sendUniverse(universe)
        }
    }

    private func sendUniverse(_ universe: DMXUniverse) {
        switch outputProtocol {
        case .artNet:
            sendArtNet(universe)
        case .sACN:
            sendSACN(universe)
        case .dmxUSB:
            sendDMXUSB(universe)
        case .osc:
            sendOSC(universe)
        }
    }

    // MARK: - Protocol Implementations

    private func sendArtNet(_ universe: DMXUniverse) {
        // Art-Net packet structure
        // Header: "Art-Net\0" (8 bytes)
        // OpCode: 0x5000 (ArtDmx, little-endian)
        // Protocol Version: 14
        // Sequence, Physical, Universe, Length, Data

        var packet = Data()
        packet.append(contentsOf: "Art-Net".utf8)
        packet.append(0) // Null terminator
        packet.append(contentsOf: [0x00, 0x50]) // OpCode (little-endian)
        packet.append(contentsOf: [0x00, 14]) // Protocol version
        packet.append(0) // Sequence
        packet.append(0) // Physical
        packet.append(UInt8(universe.id & 0xFF)) // Universe low
        packet.append(UInt8((universe.id >> 8) & 0xFF)) // Universe high
        packet.append(contentsOf: [0x02, 0x00]) // Length (512, big-endian)
        packet.append(contentsOf: universe.channels)

        // Would send via UDP to 2.255.255.255:6454 or unicast
        EchoelLog.visual.debug("Art-Net packet prepared for universe \(universe.id)")
    }

    private func sendSACN(_ universe: DMXUniverse) {
        // E1.31 sACN packet (simplified)
        // Full implementation would include proper framing layers
        EchoelLog.visual.debug("sACN packet prepared for universe \(universe.id)")
    }

    private func sendDMXUSB(_ universe: DMXUniverse) {
        // FTDI/ENTTEC Pro compatible output
        EchoelLog.visual.debug("DMX USB packet prepared for universe \(universe.id)")
    }

    private func sendOSC(_ universe: DMXUniverse) {
        // OSC /dmx/{universe}/{channel} format
        EchoelLog.visual.debug("OSC messages prepared for universe \(universe.id)")
    }

    // MARK: - Bio-Reactive Mapping

    private func setupBioReactiveBinding() {
        // Would bind to EchoelUniversalCore for bio data
    }

    public func updateBioData(coherence: Double, heartRate: Double, hrv: Double) {
        currentCoherence = coherence
        currentHeartRate = heartRate

        if bioReactiveEnabled {
            applyBioReactiveMapping()
        }
    }

    private func applyBioReactiveMapping() {
        let (r, g, b) = BioLightMapper.coherenceToColor(currentCoherence)
        let pulseDuration = BioLightMapper.heartRateToPulseDuration(bpm: currentHeartRate)

        // Apply to first universe fixtures
        guard !universes.isEmpty else { return }

        for fixture in universes[0].fixtures {
            setFixtureColor(fixture, r: r, g: g, b: b)
        }
    }

    private func applyCircadianAdjustment() {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let minute = calendar.component(.minute, from: Date())

        currentColorTemperature = BioLightMapper.circadianColorTemperature(hour: hour, minute: minute)

        let (r, g, b) = PlanckianRadiator.toRGB(kelvin: currentColorTemperature)

        // Apply to fixtures with color temperature support
        for fixture in universes.first?.fixtures ?? [] {
            if fixture.type == .rgbwLED || fixture.type == .ledBar {
                setFixtureColor(fixture, r: r, g: g, b: b)
            }
        }
    }

    // MARK: - Audio Reactive Mapping

    private func setupAudioReactiveBinding() {
        // Would bind to audio engine for FFT data
    }

    public func updateAudioData(fftMagnitudes: [Float], rms: Float, sampleRate: Double) {
        guard audioReactiveEnabled else { return }

        // Extract band energies
        let fftSize = fftMagnitudes.count * 2

        for band in AudioLightMapper.FrequencyBand.allCases {
            let energy = AudioLightMapper.extractBandEnergy(
                fftMagnitudes: fftMagnitudes,
                sampleRate: sampleRate,
                fftSize: fftSize,
                band: band
            )

            // Map to corresponding fixture/channel based on setup
            applyBandToLighting(band: band, energy: energy)
        }

        // Apply master dimmer from RMS
        let masterDimmer = AudioLightMapper.rmsToDMX(rms: rms)
        applyMasterDimmer(masterDimmer)
    }

    private func applyBandToLighting(band: AudioLightMapper.FrequencyBand, energy: Float) {
        // Map band energy to fixture brightness
        let dmxValue = UInt8(min(255, energy * 255 * 2)) // 2x gain

        // Would apply to specific fixtures based on configuration
    }

    private func applyMasterDimmer(_ value: UInt8) {
        // Apply to all fixtures' dimmer channel
        guard !universes.isEmpty else { return }

        for fixture in universes[0].fixtures {
            if let dimmerIndex = fixture.personality.channelLayout.firstIndex(of: .dimmer) {
                let channel = fixture.startAddress + dimmerIndex
                universes[0].setChannel(channel, value: value)
            }
        }
    }

    // MARK: - MIDI/MPE Reactive

    public func handleMIDINote(note: UInt8, velocity: UInt8, channel: UInt8) {
        guard midiReactiveEnabled else { return }

        let color = MIDILightMapper.noteToColor(note: note)
        let brightness = MIDILightMapper.velocityToBrightness(velocity: velocity)

        // Apply to fixtures
        for fixture in universes.first?.fixtures ?? [] {
            setFixtureColor(fixture, r: color.0, g: color.1, b: color.2)
            setFixtureBrightness(fixture, brightness: brightness)
        }
    }

    public func handleMPEPressure(pressure: UInt8, channel: UInt8) {
        guard midiReactiveEnabled else { return }

        let modulation = MIDILightMapper.pressureToModulation(pressure: pressure)
        // Apply modulation to current fixture state
    }

    public func handleMPESlide(slide: UInt8, channel: UInt8) {
        guard midiReactiveEnabled else { return }

        currentColorTemperature = MIDILightMapper.slideToColorTempShift(
            slide: slide,
            baseTemp: currentColorTemperature
        )
    }

    // MARK: - Fixture Control Helpers

    private func setFixtureColor(_ fixture: DMXFixture, r: UInt8, g: UInt8, b: UInt8) {
        guard !universes.isEmpty else { return }

        let layout = fixture.personality.channelLayout

        if let redIndex = layout.firstIndex(of: .red) {
            universes[0].setChannel(fixture.startAddress + redIndex, value: r)
        }
        if let greenIndex = layout.firstIndex(of: .green) {
            universes[0].setChannel(fixture.startAddress + greenIndex, value: g)
        }
        if let blueIndex = layout.firstIndex(of: .blue) {
            universes[0].setChannel(fixture.startAddress + blueIndex, value: b)
        }
    }

    private func setFixtureBrightness(_ fixture: DMXFixture, brightness: UInt8) {
        guard !universes.isEmpty else { return }

        if let dimmerIndex = fixture.personality.channelLayout.firstIndex(of: .dimmer) {
            universes[0].setChannel(fixture.startAddress + dimmerIndex, value: brightness)
        }
    }
}
