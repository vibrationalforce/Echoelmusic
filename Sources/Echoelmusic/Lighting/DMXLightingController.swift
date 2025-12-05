import Foundation
import Network

// MARK: - DMX Lighting Controller
// Professional DMX512 lighting control with Art-Net and sACN support
// Features: Fixture library, chase sequences, audio-reactive effects

@MainActor
public final class DMXLightingController: ObservableObject {
    public static let shared = DMXLightingController()

    @Published public private(set) var isConnected = false
    @Published public private(set) var universes: [DMXUniverse] = []
    @Published public private(set) var fixtures: [DMXFixture] = []
    @Published public private(set) var activeChases: [LightingChase] = []

    // Network connections
    private var artNetConnection: ArtNetConnection?
    private var sACNConnection: SACNConnection?

    // DMX output buffer (512 channels per universe)
    private var dmxBuffers: [Int: [UInt8]] = [:]

    // Audio reactivity
    private var audioAnalyzer: LightingAudioAnalyzer

    // Configuration
    public struct Configuration {
        public var protocol: DMXProtocol = .artNet
        public var universeCount: Int = 1
        public var refreshRate: Double = 44 // Hz (standard DMX)
        public var artNetPort: UInt16 = 6454
        public var sACNPort: UInt16 = 5568
        public var broadcastAddress: String = "255.255.255.255"

        public enum DMXProtocol {
            case artNet
            case sACN
            case both
        }

        public static let `default` = Configuration()
    }

    private var config: Configuration = .default
    private var outputTimer: Timer?

    public init() {
        self.audioAnalyzer = LightingAudioAnalyzer()
        setupUniverses()
    }

    // MARK: - Setup

    private func setupUniverses() {
        for i in 0..<config.universeCount {
            universes.append(DMXUniverse(id: i))
            dmxBuffers[i] = [UInt8](repeating: 0, count: 512)
        }
    }

    /// Connect to DMX network
    public func connect() async throws {
        switch config.protocol {
        case .artNet:
            try await connectArtNet()
        case .sACN:
            try await connectSACN()
        case .both:
            try await connectArtNet()
            try await connectSACN()
        }

        startOutputLoop()
        isConnected = true
    }

    /// Disconnect from DMX network
    public func disconnect() {
        stopOutputLoop()
        artNetConnection?.disconnect()
        sACNConnection?.disconnect()
        isConnected = false
    }

    // MARK: - Art-Net Connection

    private func connectArtNet() async throws {
        artNetConnection = ArtNetConnection(
            broadcastAddress: config.broadcastAddress,
            port: config.artNetPort
        )
        try await artNetConnection?.connect()
    }

    // MARK: - sACN Connection

    private func connectSACN() async throws {
        sACNConnection = SACNConnection(port: config.sACNPort)
        try await sACNConnection?.connect()
    }

    // MARK: - DMX Output Loop

    private func startOutputLoop() {
        outputTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0 / config.refreshRate,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.sendDMXData()
            }
        }
    }

    private func stopOutputLoop() {
        outputTimer?.invalidate()
        outputTimer = nil
    }

    private func sendDMXData() {
        for (universeId, buffer) in dmxBuffers {
            artNetConnection?.send(universe: universeId, data: buffer)
            sACNConnection?.send(universe: universeId, data: buffer)
        }
    }

    // MARK: - Fixture Management

    /// Add fixture to universe
    public func addFixture(_ fixture: DMXFixture, universe: Int = 0) {
        var newFixture = fixture
        newFixture.universe = universe
        fixtures.append(newFixture)
    }

    /// Remove fixture
    public func removeFixture(_ fixtureId: UUID) {
        fixtures.removeAll { $0.id == fixtureId }
    }

    /// Get fixture by ID
    public func getFixture(_ id: UUID) -> DMXFixture? {
        return fixtures.first { $0.id == id }
    }

    // MARK: - Channel Control

    /// Set single channel value
    public func setChannel(_ channel: Int, value: UInt8, universe: Int = 0) {
        guard channel >= 1 && channel <= 512 else { return }
        dmxBuffers[universe]?[channel - 1] = value
    }

    /// Set multiple channels
    public func setChannels(_ channels: [Int: UInt8], universe: Int = 0) {
        for (channel, value) in channels {
            setChannel(channel, value: value, universe: universe)
        }
    }

    /// Set fixture values
    public func setFixture(_ fixtureId: UUID, values: FixtureValues) {
        guard let fixture = getFixture(fixtureId) else { return }

        let startChannel = fixture.startChannel

        if let dimmer = values.dimmer {
            setChannel(startChannel + fixture.profile.dimmerOffset, value: dimmer, universe: fixture.universe)
        }

        if let red = values.red {
            setChannel(startChannel + fixture.profile.redOffset, value: red, universe: fixture.universe)
        }

        if let green = values.green {
            setChannel(startChannel + fixture.profile.greenOffset, value: green, universe: fixture.universe)
        }

        if let blue = values.blue {
            setChannel(startChannel + fixture.profile.blueOffset, value: blue, universe: fixture.universe)
        }

        if let white = values.white {
            setChannel(startChannel + fixture.profile.whiteOffset, value: white, universe: fixture.universe)
        }

        if let pan = values.pan {
            setChannel(startChannel + fixture.profile.panOffset, value: pan, universe: fixture.universe)
        }

        if let tilt = values.tilt {
            setChannel(startChannel + fixture.profile.tiltOffset, value: tilt, universe: fixture.universe)
        }

        if let strobe = values.strobe {
            setChannel(startChannel + fixture.profile.strobeOffset, value: strobe, universe: fixture.universe)
        }
    }

    /// Set all fixtures to color
    public func setAllFixtures(color: LightColor) {
        for fixture in fixtures {
            setFixture(fixture.id, values: FixtureValues(
                dimmer: 255,
                red: color.red,
                green: color.green,
                blue: color.blue
            ))
        }
    }

    /// Blackout all fixtures
    public func blackout() {
        for universe in 0..<config.universeCount {
            dmxBuffers[universe] = [UInt8](repeating: 0, count: 512)
        }
    }

    // MARK: - Chase Sequences

    /// Start a chase sequence
    public func startChase(_ chase: LightingChase) {
        activeChases.append(chase)
        runChase(chase)
    }

    /// Stop a chase sequence
    public func stopChase(_ chaseId: UUID) {
        activeChases.removeAll { $0.id == chaseId }
    }

    /// Stop all chases
    public func stopAllChases() {
        activeChases.removeAll()
    }

    private func runChase(_ chase: LightingChase) {
        guard activeChases.contains(where: { $0.id == chase.id }) else { return }

        Task {
            var stepIndex = 0

            while activeChases.contains(where: { $0.id == chase.id }) {
                let step = chase.steps[stepIndex]

                // Apply step
                for (fixtureId, values) in step.fixtureValues {
                    setFixture(fixtureId, values: values)
                }

                // Wait for step duration
                try? await Task.sleep(nanoseconds: UInt64(step.duration * 1_000_000_000))

                // Fade if specified
                if step.fadeTime > 0 {
                    // Implement fade
                }

                stepIndex = (stepIndex + 1) % chase.steps.count
            }
        }
    }

    // MARK: - Audio Reactivity

    /// Enable audio-reactive lighting
    public func enableAudioReactivity(mode: AudioReactiveMode) {
        audioAnalyzer.start { [weak self] analysis in
            Task { @MainActor in
                self?.applyAudioReactivity(analysis, mode: mode)
            }
        }
    }

    /// Disable audio reactivity
    public func disableAudioReactivity() {
        audioAnalyzer.stop()
    }

    private func applyAudioReactivity(_ analysis: AudioAnalysis, mode: AudioReactiveMode) {
        switch mode {
        case .intensity:
            // Map overall level to dimmer
            let dimmer = UInt8(analysis.level * 255)
            for fixture in fixtures {
                setFixture(fixture.id, values: FixtureValues(dimmer: dimmer))
            }

        case .colorByFrequency:
            // Map frequency bands to RGB
            let red = UInt8(analysis.lowFrequency * 255)
            let green = UInt8(analysis.midFrequency * 255)
            let blue = UInt8(analysis.highFrequency * 255)

            for fixture in fixtures {
                setFixture(fixture.id, values: FixtureValues(
                    dimmer: 255,
                    red: red,
                    green: green,
                    blue: blue
                ))
            }

        case .beatSync:
            // Flash on beat
            if analysis.isBeat {
                setAllFixtures(color: LightColor(red: 255, green: 255, blue: 255))
            } else {
                let decay = UInt8(analysis.beatDecay * 255)
                setAllFixtures(color: LightColor(red: decay, green: decay, blue: decay))
            }

        case .spectrum:
            // Map spectrum to fixture positions
            let fixtureCount = fixtures.count
            for (index, fixture) in fixtures.enumerated() {
                let bandIndex = index * analysis.spectrum.count / max(fixtureCount, 1)
                let intensity = UInt8(analysis.spectrum[min(bandIndex, analysis.spectrum.count - 1)] * 255)
                setFixture(fixture.id, values: FixtureValues(dimmer: intensity))
            }

        case .custom(let handler):
            handler(analysis, self)
        }
    }

    public enum AudioReactiveMode {
        case intensity
        case colorByFrequency
        case beatSync
        case spectrum
        case custom((AudioAnalysis, DMXLightingController) -> Void)
    }

    public func configure(_ config: Configuration) {
        self.config = config
        setupUniverses()
    }
}

// MARK: - DMX Universe

public struct DMXUniverse: Identifiable {
    public let id: Int
    public var name: String

    public init(id: Int, name: String? = nil) {
        self.id = id
        self.name = name ?? "Universe \(id + 1)"
    }
}

// MARK: - DMX Fixture

public struct DMXFixture: Identifiable {
    public let id: UUID
    public var name: String
    public var startChannel: Int
    public var universe: Int
    public var profile: FixtureProfile

    public init(
        id: UUID = UUID(),
        name: String,
        startChannel: Int,
        universe: Int = 0,
        profile: FixtureProfile
    ) {
        self.id = id
        self.name = name
        self.startChannel = startChannel
        self.universe = universe
        self.profile = profile
    }
}

// MARK: - Fixture Profile

public struct FixtureProfile {
    public let name: String
    public let channelCount: Int
    public let type: FixtureType

    // Channel offsets (0-based)
    public var dimmerOffset: Int = 0
    public var redOffset: Int = 1
    public var greenOffset: Int = 2
    public var blueOffset: Int = 3
    public var whiteOffset: Int = 4
    public var panOffset: Int = 5
    public var tiltOffset: Int = 6
    public var strobeOffset: Int = 7
    public var colorWheelOffset: Int = 8
    public var goboOffset: Int = 9

    public enum FixtureType {
        case dimmer
        case rgb
        case rgbw
        case movingHead
        case scanner
        case strobe
        case laser
        case fogMachine
        case custom
    }

    // Built-in profiles
    public static let genericDimmer = FixtureProfile(
        name: "Generic Dimmer",
        channelCount: 1,
        type: .dimmer
    )

    public static let genericRGB = FixtureProfile(
        name: "Generic RGB",
        channelCount: 4,
        type: .rgb,
        dimmerOffset: 0,
        redOffset: 1,
        greenOffset: 2,
        blueOffset: 3
    )

    public static let genericRGBW = FixtureProfile(
        name: "Generic RGBW",
        channelCount: 5,
        type: .rgbw,
        dimmerOffset: 0,
        redOffset: 1,
        greenOffset: 2,
        blueOffset: 3,
        whiteOffset: 4
    )

    public static let genericMovingHead = FixtureProfile(
        name: "Generic Moving Head",
        channelCount: 16,
        type: .movingHead,
        dimmerOffset: 0,
        redOffset: 1,
        greenOffset: 2,
        blueOffset: 3,
        whiteOffset: 4,
        panOffset: 5,
        tiltOffset: 7,
        strobeOffset: 9,
        colorWheelOffset: 10,
        goboOffset: 11
    )

    public init(
        name: String,
        channelCount: Int,
        type: FixtureType,
        dimmerOffset: Int = 0,
        redOffset: Int = 1,
        greenOffset: Int = 2,
        blueOffset: Int = 3,
        whiteOffset: Int = 4,
        panOffset: Int = 5,
        tiltOffset: Int = 6,
        strobeOffset: Int = 7,
        colorWheelOffset: Int = 8,
        goboOffset: Int = 9
    ) {
        self.name = name
        self.channelCount = channelCount
        self.type = type
        self.dimmerOffset = dimmerOffset
        self.redOffset = redOffset
        self.greenOffset = greenOffset
        self.blueOffset = blueOffset
        self.whiteOffset = whiteOffset
        self.panOffset = panOffset
        self.tiltOffset = tiltOffset
        self.strobeOffset = strobeOffset
        self.colorWheelOffset = colorWheelOffset
        self.goboOffset = goboOffset
    }
}

// MARK: - Fixture Values

public struct FixtureValues {
    public var dimmer: UInt8?
    public var red: UInt8?
    public var green: UInt8?
    public var blue: UInt8?
    public var white: UInt8?
    public var pan: UInt8?
    public var tilt: UInt8?
    public var strobe: UInt8?
    public var colorWheel: UInt8?
    public var gobo: UInt8?

    public init(
        dimmer: UInt8? = nil,
        red: UInt8? = nil,
        green: UInt8? = nil,
        blue: UInt8? = nil,
        white: UInt8? = nil,
        pan: UInt8? = nil,
        tilt: UInt8? = nil,
        strobe: UInt8? = nil,
        colorWheel: UInt8? = nil,
        gobo: UInt8? = nil
    ) {
        self.dimmer = dimmer
        self.red = red
        self.green = green
        self.blue = blue
        self.white = white
        self.pan = pan
        self.tilt = tilt
        self.strobe = strobe
        self.colorWheel = colorWheel
        self.gobo = gobo
    }
}

// MARK: - Light Color

public struct LightColor {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8
    public let white: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8, white: UInt8 = 0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.white = white
    }

    // Preset colors
    public static let red = LightColor(red: 255, green: 0, blue: 0)
    public static let green = LightColor(red: 0, green: 255, blue: 0)
    public static let blue = LightColor(red: 0, green: 0, blue: 255)
    public static let white = LightColor(red: 255, green: 255, blue: 255)
    public static let warmWhite = LightColor(red: 255, green: 200, blue: 150, white: 255)
    public static let coolWhite = LightColor(red: 200, green: 220, blue: 255, white: 255)
    public static let amber = LightColor(red: 255, green: 150, blue: 0)
    public static let cyan = LightColor(red: 0, green: 255, blue: 255)
    public static let magenta = LightColor(red: 255, green: 0, blue: 255)
    public static let yellow = LightColor(red: 255, green: 255, blue: 0)
    public static let purple = LightColor(red: 128, green: 0, blue: 255)
    public static let orange = LightColor(red: 255, green: 100, blue: 0)
    public static let pink = LightColor(red: 255, green: 100, blue: 200)
}

// MARK: - Lighting Chase

public struct LightingChase: Identifiable {
    public let id: UUID
    public var name: String
    public var steps: [ChaseStep]
    public var loop: Bool

    public init(id: UUID = UUID(), name: String, steps: [ChaseStep], loop: Bool = true) {
        self.id = id
        self.name = name
        self.steps = steps
        self.loop = loop
    }

    public struct ChaseStep {
        public var fixtureValues: [UUID: FixtureValues]
        public var duration: TimeInterval
        public var fadeTime: TimeInterval

        public init(
            fixtureValues: [UUID: FixtureValues],
            duration: TimeInterval,
            fadeTime: TimeInterval = 0
        ) {
            self.fixtureValues = fixtureValues
            self.duration = duration
            self.fadeTime = fadeTime
        }
    }
}

// MARK: - Art-Net Connection

public class ArtNetConnection {
    private let broadcastAddress: String
    private let port: UInt16
    private var connection: NWConnection?

    private let artNetHeader: [UInt8] = [
        0x41, 0x72, 0x74, 0x2D, 0x4E, 0x65, 0x74, 0x00  // "Art-Net\0"
    ]

    public init(broadcastAddress: String, port: UInt16) {
        self.broadcastAddress = broadcastAddress
        self.port = port
    }

    public func connect() async throws {
        let host = NWEndpoint.Host(broadcastAddress)
        let port = NWEndpoint.Port(rawValue: self.port)!

        connection = NWConnection(host: host, port: port, using: .udp)
        connection?.start(queue: .global())
    }

    public func disconnect() {
        connection?.cancel()
        connection = nil
    }

    public func send(universe: Int, data: [UInt8]) {
        var packet = artNetHeader
        packet.append(contentsOf: [0x00, 0x50]) // OpCode: ArtDmx (0x5000, little endian)
        packet.append(contentsOf: [0x00, 0x0E]) // Protocol version 14
        packet.append(0x00) // Sequence
        packet.append(0x00) // Physical
        packet.append(UInt8(universe & 0xFF)) // Universe low
        packet.append(UInt8((universe >> 8) & 0xFF)) // Universe high
        packet.append(UInt8((data.count >> 8) & 0xFF)) // Length high
        packet.append(UInt8(data.count & 0xFF)) // Length low
        packet.append(contentsOf: data)

        connection?.send(content: Data(packet), completion: .idempotent)
    }
}

// MARK: - sACN Connection

public class SACNConnection {
    private let port: UInt16
    private var connection: NWConnection?

    public init(port: UInt16) {
        self.port = port
    }

    public func connect() async throws {
        // sACN uses multicast
        let host = NWEndpoint.Host("239.255.0.1")
        let port = NWEndpoint.Port(rawValue: self.port)!

        connection = NWConnection(host: host, port: port, using: .udp)
        connection?.start(queue: .global())
    }

    public func disconnect() {
        connection?.cancel()
        connection = nil
    }

    public func send(universe: Int, data: [UInt8]) {
        // sACN packet structure
        var packet = [UInt8]()

        // Root layer
        packet.append(contentsOf: [0x00, 0x10]) // Preamble size
        packet.append(contentsOf: [0x00, 0x00]) // Post-amble size
        packet.append(contentsOf: "ASC-E1.17\0\0\0".utf8) // ACN Packet Identifier

        // Add flags, length, vector, CID, etc. (simplified)
        packet.append(contentsOf: [UInt8](repeating: 0, count: 100))

        // DMX data
        packet.append(contentsOf: data)

        connection?.send(content: Data(packet), completion: .idempotent)
    }
}

// MARK: - Audio Analysis

public struct AudioAnalysis {
    public var level: Float
    public var lowFrequency: Float
    public var midFrequency: Float
    public var highFrequency: Float
    public var spectrum: [Float]
    public var isBeat: Bool
    public var beatDecay: Float
}

public class LightingAudioAnalyzer {
    private var timer: Timer?
    private var callback: ((AudioAnalysis) -> Void)?
    private var lastBeatTime: TimeInterval = 0
    private var beatDecay: Float = 0

    public func start(callback: @escaping (AudioAnalysis) -> Void) {
        self.callback = callback

        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.analyze()
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func analyze() {
        // Simulated analysis (would connect to actual audio engine)
        let level = Float.random(in: 0...1)
        let low = Float.random(in: 0...1)
        let mid = Float.random(in: 0...1)
        let high = Float.random(in: 0...1)

        // Beat detection (simplified)
        let isBeat = level > 0.8 && beatDecay < 0.3
        if isBeat {
            beatDecay = 1.0
            lastBeatTime = Date().timeIntervalSince1970
        } else {
            beatDecay *= 0.95
        }

        let analysis = AudioAnalysis(
            level: level,
            lowFrequency: low,
            midFrequency: mid,
            highFrequency: high,
            spectrum: (0..<32).map { _ in Float.random(in: 0...1) },
            isBeat: isBeat,
            beatDecay: beatDecay
        )

        callback?(analysis)
    }
}
