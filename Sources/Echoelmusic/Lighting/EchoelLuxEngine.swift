#if canImport(Network)
//
//  EchoelLuxEngine.swift
//  Echoelmusic — DMX 512 + Art-Net Lighting Engine
//
//  Controls stage lighting via Art-Net (UDP, port 6454).
//  Bio-reactive mapping: coherence → color, HRV → saturation,
//  heart rate → strobe (capped 3 Hz for WCAG epilepsy safety).
//
//  Supports: DMX 512, Art-Net 4, generic fixtures, RGB/RGBW/RGBWA+UV,
//  moving heads, LED bars, laser, fog, strobe.
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
        let dim = masterDimmer

        switch fixture.type {
        case .dimmer:
            guard addr < ArtNetConstants.channelsPerUniverse else { return }
            dmxData[addr] = UInt8(Float(max(color.red, max(color.green, color.blue))) * dim)

        case .rgb, .ledBar:
            // LED Bar uses same 3-ch RGB per pixel
            guard addr + 2 < ArtNetConstants.channelsPerUniverse else { return }
            dmxData[addr] = UInt8(Float(color.red) * dim)
            dmxData[addr + 1] = UInt8(Float(color.green) * dim)
            dmxData[addr + 2] = UInt8(Float(color.blue) * dim)

        case .rgbw:
            guard addr + 3 < ArtNetConstants.channelsPerUniverse else { return }
            dmxData[addr] = UInt8(Float(color.red) * dim)
            dmxData[addr + 1] = UInt8(Float(color.green) * dim)
            dmxData[addr + 2] = UInt8(Float(color.blue) * dim)
            dmxData[addr + 3] = UInt8(Float(color.white) * dim)

        case .rgbwau:
            // 6 ch: R, G, B, White, Amber, UV
            guard addr + 5 < ArtNetConstants.channelsPerUniverse else { return }
            dmxData[addr] = UInt8(Float(color.red) * dim)
            dmxData[addr + 1] = UInt8(Float(color.green) * dim)
            dmxData[addr + 2] = UInt8(Float(color.blue) * dim)
            dmxData[addr + 3] = UInt8(Float(color.white) * dim)
            // Amber: warm blend from red+green
            let amber = UInt8(min(Float(color.red), Float(color.green)) * dim * 0.5)
            dmxData[addr + 4] = amber
            // UV: inverse of white warmth (cool = more UV)
            dmxData[addr + 5] = UInt8(Float(255 - color.white) * dim * 0.3)

        case .movingHead:
            // 8 ch: pan, tilt, R, G, B, dimmer, strobe, gobo
            guard addr + 7 < ArtNetConstants.channelsPerUniverse else { return }
            // Pan/tilt retain current values (set via setMovingHeadPosition)
            dmxData[addr + 2] = UInt8(Float(color.red) * dim)
            dmxData[addr + 3] = UInt8(Float(color.green) * dim)
            dmxData[addr + 4] = UInt8(Float(color.blue) * dim)
            dmxData[addr + 5] = UInt8(255.0 * dim) // dimmer
            // strobe + gobo retain current values

        case .laser:
            // 5 ch: on/off, color(R), color(G), color(B), pattern
            guard addr + 4 < ArtNetConstants.channelsPerUniverse else { return }
            let brightness = max(color.red, max(color.green, color.blue))
            dmxData[addr] = brightness > 0 ? UInt8(255.0 * dim) : 0  // on/off
            dmxData[addr + 1] = UInt8(Float(color.red) * dim)
            dmxData[addr + 2] = UInt8(Float(color.green) * dim)
            dmxData[addr + 3] = UInt8(Float(color.blue) * dim)
            // pattern channel retains current value

        case .fogMachine:
            // 2 ch: intensity, fan speed
            guard addr + 1 < ArtNetConstants.channelsPerUniverse else { return }
            let intensity = Float(max(color.red, max(color.green, color.blue))) * dim
            dmxData[addr] = UInt8(intensity)
            // Fan speed proportional to intensity (min 30% when active to prevent burnout)
            dmxData[addr + 1] = intensity > 0 ? UInt8(max(76, intensity * 0.8)) : 0

        case .strobeLight:
            guard addr + 1 < ArtNetConstants.channelsPerUniverse else { return }
            dmxData[addr] = UInt8(Float(color.red) * dim)
            // Strobe rate channel — cap at 3 Hz for WCAG epilepsy safety
            dmxData[addr + 1] = min(UInt8(maxStrobeHz / 25.0 * 255.0), color.green)
        }
    }

    /// Set moving head pan/tilt position (0-1 normalized)
    public func setMovingHeadPosition(_ fixture: DMXFixture, pan: Float, tilt: Float) {
        guard fixture.type == .movingHead, fixture.isEnabled else { return }
        let addr = Int(fixture.startAddress) - 1
        guard addr + 1 < ArtNetConstants.channelsPerUniverse else { return }
        dmxData[addr] = UInt8(max(0, min(1, pan)) * 255)
        dmxData[addr + 1] = UInt8(max(0, min(1, tilt)) * 255)
    }

    /// Set moving head gobo pattern (0-255)
    public func setMovingHeadGobo(_ fixture: DMXFixture, gobo: UInt8) {
        guard fixture.type == .movingHead, fixture.isEnabled else { return }
        let addr = Int(fixture.startAddress) - 1
        guard addr + 7 < ArtNetConstants.channelsPerUniverse else { return }
        dmxData[addr + 7] = gobo
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

    /// Add a fixture
    public func addFixture(name: String, type: DMXFixtureType, startAddress: UInt16) {
        let fixture = DMXFixture(name: name, type: type, startAddress: startAddress)
        fixtures.append(fixture)
        log.log(.info, category: .audio, "Added fixture: \(name) (\(type.rawValue)) @\(startAddress)")
    }

    /// Remove a fixture by ID
    public func removeFixture(id: UUID) {
        fixtures.removeAll { $0.id == id }
    }

    /// Toggle fixture enabled state
    public func toggleFixture(id: UUID) {
        guard let index = fixtures.firstIndex(where: { $0.id == id }) else { return }
        fixtures[index].isEnabled.toggle()
    }

    /// Save current fixture colors as a scene
    public func saveScene(name: String) {
        var colors: [UUID: LightColor] = [:]
        for fixture in fixtures {
            let addr = Int(fixture.startAddress) - 1
            guard addr >= 0, addr < ArtNetConstants.channelsPerUniverse else { continue }
            switch fixture.type {
            case .rgb:
                guard addr + 2 < ArtNetConstants.channelsPerUniverse else { continue }
                colors[fixture.id] = LightColor(red: dmxData[addr], green: dmxData[addr + 1], blue: dmxData[addr + 2])
            case .rgbw:
                guard addr + 3 < ArtNetConstants.channelsPerUniverse else { continue }
                colors[fixture.id] = LightColor(red: dmxData[addr], green: dmxData[addr + 1], blue: dmxData[addr + 2], white: dmxData[addr + 3])
            default:
                colors[fixture.id] = LightColor(red: dmxData[addr])
            }
        }
        scenes.append(LightingScene(name: name, fixtures: colors))
    }

    /// Recall a scene by index
    public func recallScene(_ index: Int) {
        guard index >= 0, index < scenes.count else { return }
        activeSceneIndex = index
        let scene = scenes[index]
        for fixture in fixtures {
            if let color = scene.fixtures[fixture.id] {
                setColor(fixture, color: color)
            }
        }
    }

    /// Compute next available DMX address
    public var nextAvailableAddress: UInt16 {
        let usedRanges = fixtures.map { (start: Int($0.startAddress), end: Int($0.startAddress) + $0.type.channelCount) }
        var addr: UInt16 = 1
        for range in usedRanges.sorted(by: { $0.start < $1.start }) {
            if addr >= range.start && addr < range.end {
                addr = UInt16(range.end)
            }
        }
        return min(addr, UInt16(ArtNetConstants.channelsPerUniverse))
    }

    /// Send Art-Net poll to discover devices on the network
    public func sendPoll() {
        var packet = Data()
        packet.append(contentsOf: ArtNetConstants.protocolID)
        var opCode = ArtNetConstants.opPoll
        packet.append(Data(bytes: &opCode, count: 2))
        packet.append(ArtNetConstants.protocolVersionHi)
        packet.append(ArtNetConstants.protocolVersionLo)
        // TalkToMe flags (0 = default)
        packet.append(0)
        // Priority (0 = default)
        packet.append(0)

        connection?.send(content: packet, completion: .contentProcessed { error in
            if let error = error {
                log.log(.error, category: .audio, "Art-Net poll error: \(error.localizedDescription)")
            }
        })
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
    @State private var showAddFixture = false
    @State private var newFixtureName = ""
    @State private var newFixtureType: DMXFixtureType = .rgb
    @State private var newSceneName = ""

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: EchoelSpacing.md) {
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
                .echoelSurface()

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
                .echoelSurface()

                // Bio-reactive toggle
                Toggle("Bio-Reactive", isOn: $lux.bioReactiveEnabled)
                    .font(EchoelBrandFont.body())
                    .echoelSurface()

                // Fixture list
                VStack(alignment: .leading, spacing: EchoelSpacing.sm) {
                    HStack {
                        Text("Fixtures")
                            .font(EchoelBrandFont.label())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(action: { showAddFixture.toggle() }) {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(EchoelBrand.accent)
                        }
                        .buttonStyle(.plain)
                    }

                    if showAddFixture {
                        VStack(spacing: EchoelSpacing.sm) {
                            TextField("Fixture name", text: $newFixtureName)
                                .textFieldStyle(.roundedBorder)
                                .font(EchoelBrandFont.body())
                            Picker("Type", selection: $newFixtureType) {
                                ForEach(DMXFixtureType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                            Button("Add") {
                                guard !newFixtureName.isEmpty else { return }
                                lux.addFixture(name: newFixtureName, type: newFixtureType, startAddress: lux.nextAvailableAddress)
                                newFixtureName = ""
                                showAddFixture = false
                            }
                            .font(EchoelBrandFont.body())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, EchoelSpacing.xs)
                            .background(EchoelBrand.accent.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: EchoelRadius.sm))
                        }
                        .padding(.bottom, EchoelSpacing.sm)
                    }

                    ForEach(lux.fixtures) { fixture in
                        HStack {
                            Button(action: { lux.toggleFixture(id: fixture.id) }) {
                                Circle()
                                    .fill(fixture.isEnabled ? Color.green : Color.gray)
                                    .frame(width: 6, height: 6)
                            }
                            .buttonStyle(.plain)
                            Text(fixture.name)
                                .font(EchoelBrandFont.body())
                            Spacer()
                            Text("\(fixture.type.rawValue) @\(fixture.startAddress)")
                                .font(EchoelBrandFont.dataSmall())
                                .foregroundStyle(.secondary)
                            Button(action: { lux.removeFixture(id: fixture.id) }) {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .echoelSurface()

                // Scene presets
                VStack(alignment: .leading, spacing: EchoelSpacing.sm) {
                    Text("Scenes")
                        .font(EchoelBrandFont.label())
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: EchoelSpacing.sm) {
                            ForEach(Array(lux.scenes.enumerated()), id: \.element.id) { index, scene in
                                Button(action: { lux.recallScene(index) }) {
                                    Text(scene.name)
                                        .font(EchoelBrandFont.dataSmall())
                                        .padding(.horizontal, EchoelSpacing.sm)
                                        .padding(.vertical, EchoelSpacing.xs)
                                        .background(
                                            RoundedRectangle(cornerRadius: EchoelRadius.sm)
                                                .fill(index == lux.activeSceneIndex ? EchoelBrand.accent.opacity(0.2) : EchoelBrand.bgElevated)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: EchoelRadius.sm)
                                                        .stroke(index == lux.activeSceneIndex ? EchoelBrand.accent : EchoelBrand.border, lineWidth: 1)
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    HStack {
                        TextField("New scene", text: $newSceneName)
                            .textFieldStyle(.roundedBorder)
                            .font(EchoelBrandFont.dataSmall())
                        Button("Save") {
                            guard !newSceneName.isEmpty else { return }
                            lux.saveScene(name: newSceneName)
                            newSceneName = ""
                        }
                        .font(EchoelBrandFont.dataSmall())
                    }
                }
                .echoelSurface()

                // Control buttons
                HStack(spacing: EchoelSpacing.md) {
                    Button(action: {
                        if lux.isRunning { lux.stop() } else { lux.start() }
                    }) {
                        Label(lux.isRunning ? "Stop" : "Start", systemImage: lux.isRunning ? "stop.fill" : "play.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, EchoelSpacing.sm)
                            .background(lux.isRunning ? EchoelBrand.coral.opacity(0.2) : EchoelBrand.emerald.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: EchoelRadius.sm))
                            .overlay(
                                RoundedRectangle(cornerRadius: EchoelRadius.sm)
                                    .stroke(lux.isRunning ? EchoelBrand.coral : EchoelBrand.emerald, lineWidth: 1)
                            )
                    }

                    Button(action: { lux.blackout() }) {
                        Label("Blackout", systemImage: "moon.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, EchoelSpacing.sm)
                            .background(EchoelBrand.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: EchoelRadius.sm))
                            .overlay(
                                RoundedRectangle(cornerRadius: EchoelRadius.sm)
                                    .stroke(EchoelBrand.border, lineWidth: 1)
                            )
                    }
                }
                .font(EchoelBrandFont.body())
                .buttonStyle(.plain)

                // Safety warning
                Text("Flash rate limited to 3 Hz (WCAG 2.3.1)")
                    .font(EchoelBrandFont.dataSmall())
                    .foregroundStyle(.secondary)
            }
        }
    }
}
#endif

#endif // canImport(Network)
