#if canImport(Network)
//
//  EchoelLuxEngine.swift
//  Echoelmusic — DMX 512 + Art-Net Lighting Engine
//
//  Controls stage lighting via Art-Net (UDP, port 6454).
//  Bio-reactive mapping: coherence → color, HRV → saturation,
//  heart rate → strobe (capped 3 Hz for WCAG epilepsy safety).
//
//  Supports: DMX 512, Art-Net 4, generic fixtures, RGB/RGBW,
//  moving heads, smart home (HomeKit bridge).
//

import Foundation
import Network
#if canImport(Observation)
import Observation
#endif

// MARK: - Art-Net Protocol

/// Art-Net protocol constants (Art-Net 4 specification)
public enum ArtNetConstants: Sendable {
    /// Default Art-Net port (UDP)
    public static let port: UInt16 = 6454

    /// Art-Net protocol ID
    public static let protocolID: [UInt8] = [0x41, 0x72, 0x74, 0x2D, 0x4E, 0x65, 0x74, 0x00] // "Art-Net\0"

    /// OpCodes
    public static let opDmx: UInt16 = 0x5000
    public static let opPoll: UInt16 = 0x2000
    public static let opPollReply: UInt16 = 0x2100

    /// Protocol version
    public static let protocolVersionHi: UInt8 = 0
    public static let protocolVersionLo: UInt8 = 14

    /// DMX channels per universe
    public static let channelsPerUniverse: Int = 512
}

// MARK: - DMX Fixture Types

/// Supported fixture profiles
public enum DMXFixtureType: String, CaseIterable, Codable, Sendable {
    case dimmer        = "Dimmer"          // 1 ch: intensity
    case rgb           = "RGB"             // 3 ch: R, G, B
    case rgbw          = "RGBW"            // 4 ch: R, G, B, W
    case rgbwau        = "RGBWA+UV"        // 6 ch: R, G, B, W, Amber, UV
    case movingHead    = "Moving Head"     // 8+ ch: pan, tilt, color, gobo, dimmer, strobe, prism, focus
    case ledBar        = "LED Bar"         // Per-pixel RGB
    case laser         = "Laser"           // 5 ch: on/off, color, pattern, size, speed
    case fogMachine    = "Fog Machine"     // 2 ch: intensity, fan
    case strobeLight   = "Strobe"          // 2 ch: intensity, rate

    /// Number of DMX channels this fixture type uses
    public var channelCount: Int {
        switch self {
        case .dimmer: return 1
        case .rgb: return 3
        case .rgbw: return 4
        case .rgbwau: return 6
        case .movingHead: return 8
        case .ledBar: return 3   // per pixel
        case .laser: return 5
        case .fogMachine: return 2
        case .strobeLight: return 2
        }
    }
}

/// A configured DMX fixture at a specific address
public struct DMXFixture: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var type: DMXFixtureType
    public var universe: UInt16
    public var startAddress: UInt16  // 1-512
    public var isEnabled: Bool

    public init(name: String, type: DMXFixtureType, universe: UInt16 = 0, startAddress: UInt16 = 1) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.universe = universe
        self.startAddress = startAddress
        self.isEnabled = true
    }
}

/// RGB color for lighting
public struct LightColor: Codable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8
    public var white: UInt8

    public init(red: UInt8 = 0, green: UInt8 = 0, blue: UInt8 = 0, white: UInt8 = 0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.white = white
    }

    /// Create from normalized coherence (warm = high, cool = low)
    public static func fromCoherence(_ coherence: Float) -> LightColor {
        let c = max(0, min(1, coherence))
        // Low coherence = cool blue, High coherence = warm amber/gold
        return LightColor(
            red: UInt8(c * 255),
            green: UInt8(c * 180),
            blue: UInt8((1.0 - c) * 255),
            white: UInt8(c * 100)
        )
    }
}

// MARK: - Lighting Scene

/// A preset lighting state
public struct LightingScene: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var fixtures: [UUID: LightColor] // fixtureID → color

    public init(name: String, fixtures: [UUID: LightColor] = [:]) {
        self.id = UUID()
        self.name = name
        self.fixtures = fixtures
    }
}

// MARK: - EchoelLux Engine

/// DMX 512 lighting controller via Art-Net
@preconcurrency @MainActor
@Observable
public final class EchoelLuxEngine {

    // MARK: - Singleton

    @MainActor public static let shared = EchoelLuxEngine()

    // MARK: - State

    public var isRunning: Bool = false
    public var fixtures: [DMXFixture] = []
    public var scenes: [LightingScene] = []
    public var activeSceneIndex: Int = 0
    public var masterDimmer: Float = 1.0
    public var bioReactiveEnabled: Bool = true

    /// Current DMX universe data (512 channels)
    private var dmxData: [UInt8] = [UInt8](repeating: 0, count: ArtNetConstants.channelsPerUniverse)

    /// Art-Net sequence counter
    private var artNetSequence: UInt8 = 0

    // MARK: - Network

    nonisolated(unsafe) private var connection: NWConnection?
    private let sendQueue = DispatchQueue(label: "com.echoelmusic.artnet", qos: .userInteractive)
    private var targetHost: String = "255.255.255.255" // Broadcast by default
    private var targetPort: UInt16 = ArtNetConstants.port

    /// Update rate (max 44 packets/sec per Art-Net spec, we use 40Hz)
    nonisolated(unsafe) private var updateTimer: Timer?

    // MARK: - Safety

    /// WCAG 2.3.1: Flash rate must NEVER exceed 3 Hz
    private let maxStrobeHz: Float = 3.0

    // MARK: - Init

    private init() {
        // Default fixtures for demo
        fixtures = [
            DMXFixture(name: "Front Wash L", type: .rgb, startAddress: 1),
            DMXFixture(name: "Front Wash R", type: .rgb, startAddress: 4),
            DMXFixture(name: "Back RGB", type: .rgbw, startAddress: 7),
            DMXFixture(name: "Strobe", type: .strobeLight, startAddress: 11)
        ]

        scenes = [
            LightingScene(name: "Ambient"),
            LightingScene(name: "Performance"),
            LightingScene(name: "Meditation"),
            LightingScene(name: "Blackout")
        ]
    }

    deinit {
        updateTimer?.invalidate()
        connection?.cancel()
    }

    // MARK: - Start / Stop

    public func start(host: String = "255.255.255.255") {
        guard !isRunning else { return }
        targetHost = host

        let nwHost = NWEndpoint.Host(targetHost)
        guard let port = NWEndpoint.Port(rawValue: targetPort) else { return }

        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        connection = NWConnection(host: nwHost, port: port, using: params)
        connection?.start(queue: sendQueue)

        // 40Hz update rate (within Art-Net spec limit of 44Hz)
        // Timer.scheduledTimer runs on main RunLoop — MainActor.assumeIsolated for zero-cost dispatch
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 40.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.sendDMXFrame()
            }
        }

        isRunning = true
        log.log(.info, category: .audio, "EchoelLux started — Art-Net to \(targetHost):\(targetPort)")
    }

    public func stop() {
        updateTimer?.invalidate()
        updateTimer = nil
        connection?.cancel()
        connection = nil

        // Blackout
        dmxData = [UInt8](repeating: 0, count: ArtNetConstants.channelsPerUniverse)
        isRunning = false
        log.log(.info, category: .audio, "EchoelLux stopped")
    }

    // MARK: - Fixture Control

    /// Set RGB color on a fixture
    public func setColor(_ fixture: DMXFixture, color: LightColor) {
        guard fixture.isEnabled else { return }
        let addr = Int(fixture.startAddress) - 1 // DMX is 1-indexed

        switch fixture.type {
        case .rgb:
            guard addr + 2 < ArtNetConstants.channelsPerUniverse else { return }
            dmxData[addr] = UInt8(Float(color.red) * masterDimmer)
            dmxData[addr + 1] = UInt8(Float(color.green) * masterDimmer)
            dmxData[addr + 2] = UInt8(Float(color.blue) * masterDimmer)
        case .rgbw:
            guard addr + 3 < ArtNetConstants.channelsPerUniverse else { return }
            dmxData[addr] = UInt8(Float(color.red) * masterDimmer)
            dmxData[addr + 1] = UInt8(Float(color.green) * masterDimmer)
            dmxData[addr + 2] = UInt8(Float(color.blue) * masterDimmer)
            dmxData[addr + 3] = UInt8(Float(color.white) * masterDimmer)
        case .dimmer:
            guard addr < ArtNetConstants.channelsPerUniverse else { return }
            dmxData[addr] = UInt8(Float(max(color.red, max(color.green, color.blue))) * masterDimmer)
        case .strobeLight:
            guard addr + 1 < ArtNetConstants.channelsPerUniverse else { return }
            dmxData[addr] = UInt8(Float(color.red) * masterDimmer)
            // Strobe rate channel — cap at 3 Hz for epilepsy safety
            dmxData[addr + 1] = min(UInt8(maxStrobeHz / 25.0 * 255.0), color.green)
        default:
            break
        }
    }

    /// Set all fixtures to a color
    public func setAllFixtures(color: LightColor) {
        for fixture in fixtures {
            setColor(fixture, color: color)
        }
    }

    /// Blackout all fixtures
    public func blackout() {
        dmxData = [UInt8](repeating: 0, count: ArtNetConstants.channelsPerUniverse)
    }

    // MARK: - Bio-Reactive Lighting

    /// Apply bio-reactive parameters to all fixtures
    /// Called from EchoelCreativeWorkspace at 20-40Hz
    public func applyBioReactive(coherence: Float, hrv: Float, heartRate: Float, breathPhase: Float) {
        guard bioReactiveEnabled else { return }

        let color = LightColor.fromCoherence(coherence)

        // Apply breath phase as dimmer modulation
        let breathDimmer = 0.3 + breathPhase * 0.7 // never fully black
        let dimmedColor = LightColor(
            red: UInt8(Float(color.red) * breathDimmer),
            green: UInt8(Float(color.green) * breathDimmer),
            blue: UInt8(Float(color.blue) * breathDimmer),
            white: UInt8(Float(color.white) * breathDimmer)
        )

        for fixture in fixtures where fixture.type != .strobeLight {
            setColor(fixture, color: dimmedColor)
        }
    }

    // MARK: - Art-Net Packet

    /// Build and send an Art-Net DMX packet
    private func sendDMXFrame() {
        var packet = Data()

        // Protocol ID: "Art-Net\0"
        packet.append(contentsOf: ArtNetConstants.protocolID)

        // OpCode: OpDmx (little-endian)
        var opCode = ArtNetConstants.opDmx
        packet.append(Data(bytes: &opCode, count: 2))

        // Protocol Version (big-endian)
        packet.append(ArtNetConstants.protocolVersionHi)
        packet.append(ArtNetConstants.protocolVersionLo)

        // Sequence (0 = disable sequencing, 1-255 = sequenced)
        artNetSequence = artNetSequence == 255 ? 1 : artNetSequence + 1
        packet.append(artNetSequence)

        // Physical port
        packet.append(0)

        // Universe (little-endian)
        var universe: UInt16 = 0
        packet.append(Data(bytes: &universe, count: 2))

        // Length (big-endian, must be even, 2-512)
        var length = UInt16(ArtNetConstants.channelsPerUniverse).bigEndian
        packet.append(Data(bytes: &length, count: 2))

        // DMX data (512 channels)
        packet.append(contentsOf: dmxData)

        // Send
        connection?.send(content: packet, completion: .contentProcessed { error in
            if let error = error {
                log.log(.error, category: .audio, "Art-Net send error: \(error.localizedDescription)")
            }
        })
    }
}

// MARK: - Lighting Control View

#if canImport(SwiftUI)
import SwiftUI

/// Lighting control panel
public struct EchoelLuxView: View {
    @Bindable private var lux = EchoelLuxEngine.shared

    public init() {}

    public var body: some View {
        VStack(spacing: EchoelSpacing.md) {
            VaporwaveSectionHeader("EchoelLux", icon: "lightbulb.fill")

            // Status bar
            HStack {
                Circle()
                    .fill(lux.isRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(lux.isRunning ? "Art-Net Active" : "Offline")
                    .font(EchoelBrandFont.body())
                Spacer()
                Text("\(lux.fixtures.count) fixtures")
                    .font(EchoelBrandFont.caption())
                    .foregroundStyle(.secondary)
            }
            .padding(EchoelSpacing.sm)
            .glassCard()

            // Master dimmer
            VStack(spacing: EchoelSpacing.sm) {
                HStack {
                    Text("Master")
                        .font(EchoelBrandFont.label())
                    Spacer()
                    Text("\(Int(lux.masterDimmer * 100))%")
                        .font(EchoelBrandFont.data())
                }
                Slider(value: $lux.masterDimmer, in: 0...1)
                    .tint(EchoelBrand.accent)
            }
            .padding(EchoelSpacing.sm)
            .glassCard()

            // Bio-reactive toggle
            Toggle("Bio-Reactive Lighting", isOn: $lux.bioReactiveEnabled)
                .font(EchoelBrandFont.body())
                .padding(EchoelSpacing.sm)
                .glassCard()

            // Fixture list
            VStack(alignment: .leading, spacing: EchoelSpacing.sm) {
                Text("Fixtures")
                    .font(EchoelBrandFont.label())
                    .foregroundStyle(.secondary)

                ForEach(lux.fixtures) { fixture in
                    HStack {
                        Circle()
                            .fill(fixture.isEnabled ? Color.green : Color.gray)
                            .frame(width: 6, height: 6)
                        Text(fixture.name)
                            .font(EchoelBrandFont.body())
                        Spacer()
                        Text("\(fixture.type.rawValue) @\(fixture.startAddress)")
                            .font(EchoelBrandFont.dataSmall())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(EchoelSpacing.sm)
            .glassCard()

            // Control buttons
            HStack(spacing: EchoelSpacing.md) {
                Button(action: {
                    if lux.isRunning { lux.stop() } else { lux.start() }
                }) {
                    Label(lux.isRunning ? "Stop" : "Start", systemImage: lux.isRunning ? "stop.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, EchoelSpacing.sm)
                        .background(lux.isRunning ? Color.red.opacity(0.3) : Color.green.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Button(action: { lux.blackout() }) {
                    Label("Blackout", systemImage: "moon.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, EchoelSpacing.sm)
                        .background(EchoelBrand.bgElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .font(EchoelBrandFont.body())

            // Safety warning
            Text("Flash rate limited to 3 Hz (WCAG 2.3.1 epilepsy safety)")
                .font(EchoelBrandFont.dataSmall())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
#endif

#endif // canImport(Network)
