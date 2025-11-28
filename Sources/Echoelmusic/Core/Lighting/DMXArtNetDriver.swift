//
//  DMXArtNetDriver.swift
//  Echoelmusic
//
//  Created: 2025-11-28
//  Professional Lighting Protocol Implementation
//
//  Supports: DMX512, Art-Net, sACN (E1.31)
//  Ultra-low latency lighting control for immersive experiences
//

import Foundation
import Network

// MARK: - DMX512 Protocol

/// DMX512 Universe representation (512 channels)
public struct DMXUniverse {
    public static let channelCount = 512

    /// Channel values (0-255)
    public var channels: [UInt8]

    /// Universe number (0-32767)
    public let universeNumber: Int

    /// Timestamp for sync
    public var timestamp: UInt64

    public init(universeNumber: Int) {
        self.universeNumber = universeNumber
        self.channels = [UInt8](repeating: 0, count: DMXUniverse.channelCount)
        self.timestamp = 0
    }

    /// Set channel value with bounds checking
    public mutating func setChannel(_ channel: Int, value: UInt8) {
        guard channel >= 1 && channel <= DMXUniverse.channelCount else { return }
        channels[channel - 1] = value  // DMX is 1-indexed
    }

    /// Get channel value
    public func getChannel(_ channel: Int) -> UInt8 {
        guard channel >= 1 && channel <= DMXUniverse.channelCount else { return 0 }
        return channels[channel - 1]
    }

    /// Set RGB fixture (3 consecutive channels)
    public mutating func setRGB(startChannel: Int, r: UInt8, g: UInt8, b: UInt8) {
        setChannel(startChannel, value: r)
        setChannel(startChannel + 1, value: g)
        setChannel(startChannel + 2, value: b)
    }

    /// Set RGBW fixture (4 consecutive channels)
    public mutating func setRGBW(startChannel: Int, r: UInt8, g: UInt8, b: UInt8, w: UInt8) {
        setChannel(startChannel, value: r)
        setChannel(startChannel + 1, value: g)
        setChannel(startChannel + 2, value: b)
        setChannel(startChannel + 3, value: w)
    }

    /// Set dimmer + RGB fixture (4 consecutive channels)
    public mutating func setDimmerRGB(startChannel: Int, dimmer: UInt8, r: UInt8, g: UInt8, b: UInt8) {
        setChannel(startChannel, value: dimmer)
        setChannel(startChannel + 1, value: r)
        setChannel(startChannel + 2, value: g)
        setChannel(startChannel + 3, value: b)
    }
}

// MARK: - Art-Net Protocol

/// Art-Net 4 protocol implementation
/// UDP-based lighting control protocol
@MainActor
public final class ArtNetDriver: ObservableObject, LightingProtocolDriver {
    // MARK: - Constants

    private static let artNetPort: UInt16 = 6454
    private static let artNetHeader: [UInt8] = [0x41, 0x72, 0x74, 0x2D, 0x4E, 0x65, 0x74, 0x00]  // "Art-Net\0"

    // OpCodes
    private static let opPoll: UInt16 = 0x2000
    private static let opPollReply: UInt16 = 0x2100
    private static let opDmx: UInt16 = 0x5000
    private static let opSync: UInt16 = 0x5200

    // MARK: - Properties

    public let protocolName = "Art-Net"
    @Published public private(set) var isConnected = false
    @Published public private(set) var discoveredNodes: [ArtNetNode] = []

    private var connection: NWConnection?
    private var listener: NWListener?
    private var universes: [Int: DMXUniverse] = [:]
    private var sequenceNumber: UInt8 = 0
    private let sendQueue = DispatchQueue(label: "com.eoel.artnet.send", qos: .userInteractive)

    // MARK: - Art-Net Node

    public struct ArtNetNode: Identifiable, Hashable {
        public let id: String
        public let ipAddress: String
        public let shortName: String
        public let longName: String
        public let numPorts: Int
        public let macAddress: String
        public let firmwareVersion: UInt16
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Connection

    public func connect() async throws {
        // Create UDP listener for node discovery responses
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true

        listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: Self.artNetPort))
        listener?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.isConnected = state == .ready
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleIncomingConnection(connection)
        }

        listener?.start(queue: .main)

        // Send ArtPoll to discover nodes
        try await sendArtPoll()

        isConnected = true
    }

    public func disconnect() {
        listener?.cancel()
        listener = nil
        connection?.cancel()
        connection = nil
        isConnected = false
        discoveredNodes.removeAll()
    }

    // MARK: - DMX Transmission

    public func sendDMXUniverse(_ universe: Int, channels: [UInt8]) async throws {
        guard isConnected else { throw ArtNetError.notConnected }
        guard channels.count == 512 else { throw ArtNetError.invalidDataLength }

        // Build ArtDmx packet
        var packet = [UInt8]()

        // Header: "Art-Net\0"
        packet.append(contentsOf: Self.artNetHeader)

        // OpCode: OpDmx (0x5000) - Little Endian
        packet.append(UInt8(Self.opDmx & 0xFF))
        packet.append(UInt8((Self.opDmx >> 8) & 0xFF))

        // Protocol Version: 14 (Big Endian)
        packet.append(0x00)
        packet.append(0x0E)

        // Sequence: For re-ordering packets (0 = disable)
        sequenceNumber = sequenceNumber &+ 1
        if sequenceNumber == 0 { sequenceNumber = 1 }
        packet.append(sequenceNumber)

        // Physical: Input port (0)
        packet.append(0x00)

        // Universe: Sub-Net + Universe (Little Endian)
        let subUni = UInt16(universe & 0x7FFF)
        packet.append(UInt8(subUni & 0xFF))
        packet.append(UInt8((subUni >> 8) & 0xFF))

        // Length: Number of DMX channels (Big Endian)
        packet.append(0x02)  // 512 >> 8
        packet.append(0x00)  // 512 & 0xFF

        // DMX data (512 bytes)
        packet.append(contentsOf: channels)

        // Send to broadcast address
        try await sendPacket(packet, to: "255.255.255.255")

        // Store universe state
        var dmxUniverse = universes[universe] ?? DMXUniverse(universeNumber: universe)
        dmxUniverse.channels = channels
        dmxUniverse.timestamp = mach_absolute_time()
        universes[universe] = dmxUniverse
    }

    public func setChannel(_ universe: Int, channel: Int, value: UInt8) async throws {
        var dmxUniverse = universes[universe] ?? DMXUniverse(universeNumber: universe)
        dmxUniverse.setChannel(channel, value: value)
        universes[universe] = dmxUniverse

        try await sendDMXUniverse(universe, channels: dmxUniverse.channels)
    }

    public func getChannelValues(_ universe: Int) -> [UInt8] {
        universes[universe]?.channels ?? [UInt8](repeating: 0, count: 512)
    }

    // MARK: - Art-Net Sync

    /// Send ArtSync to synchronize all nodes
    public func sendSync() async throws {
        guard isConnected else { throw ArtNetError.notConnected }

        var packet = [UInt8]()

        // Header
        packet.append(contentsOf: Self.artNetHeader)

        // OpCode: OpSync
        packet.append(UInt8(Self.opSync & 0xFF))
        packet.append(UInt8((Self.opSync >> 8) & 0xFF))

        // Protocol Version
        packet.append(0x00)
        packet.append(0x0E)

        // Aux1, Aux2 (reserved)
        packet.append(0x00)
        packet.append(0x00)

        try await sendPacket(packet, to: "255.255.255.255")
    }

    // MARK: - Node Discovery

    private func sendArtPoll() async throws {
        var packet = [UInt8]()

        // Header
        packet.append(contentsOf: Self.artNetHeader)

        // OpCode: OpPoll
        packet.append(UInt8(Self.opPoll & 0xFF))
        packet.append(UInt8((Self.opPoll >> 8) & 0xFF))

        // Protocol Version
        packet.append(0x00)
        packet.append(0x0E)

        // Flags: Send me ArtPollReply, diagnostics broadcast
        packet.append(0x06)

        // DiagPriority: Low (0x10)
        packet.append(0x10)

        // TargetPortAddress (Top, Bottom) - broadcast to all
        packet.append(0x00)
        packet.append(0x00)

        try await sendPacket(packet, to: "255.255.255.255")
    }

    private func handleIncomingConnection(_ connection: NWConnection) {
        connection.start(queue: .main)

        connection.receiveMessage { [weak self] data, _, _, error in
            guard let data = data, error == nil else { return }
            self?.parseArtNetPacket(data)
        }
    }

    private func parseArtNetPacket(_ data: Data) {
        guard data.count >= 12 else { return }

        let bytes = [UInt8](data)

        // Verify Art-Net header
        guard bytes.prefix(8).elementsEqual(Self.artNetHeader) else { return }

        // Get OpCode (Little Endian)
        let opCode = UInt16(bytes[8]) | (UInt16(bytes[9]) << 8)

        switch opCode {
        case Self.opPollReply:
            parseArtPollReply(bytes)
        default:
            break
        }
    }

    private func parseArtPollReply(_ bytes: [UInt8]) {
        guard bytes.count >= 239 else { return }

        // IP Address (bytes 10-13)
        let ip = "\(bytes[10]).\(bytes[11]).\(bytes[12]).\(bytes[13])"

        // Short Name (bytes 26-43, null-terminated)
        let shortNameBytes = Array(bytes[26..<44])
        let shortName = String(bytes: shortNameBytes, encoding: .ascii)?.trimmingCharacters(in: .controlCharacters) ?? ""

        // Long Name (bytes 44-107, null-terminated)
        let longNameBytes = Array(bytes[44..<108])
        let longName = String(bytes: longNameBytes, encoding: .ascii)?.trimmingCharacters(in: .controlCharacters) ?? ""

        // Number of ports (byte 173)
        let numPorts = Int(bytes[173])

        // MAC Address (bytes 201-206)
        let mac = String(format: "%02X:%02X:%02X:%02X:%02X:%02X",
                        bytes[201], bytes[202], bytes[203], bytes[204], bytes[205], bytes[206])

        // Firmware Version (bytes 16-17)
        let firmware = UInt16(bytes[16]) << 8 | UInt16(bytes[17])

        let node = ArtNetNode(
            id: mac,
            ipAddress: ip,
            shortName: shortName,
            longName: longName,
            numPorts: numPorts,
            macAddress: mac,
            firmwareVersion: firmware
        )

        // Add to discovered nodes (on main actor)
        Task { @MainActor in
            if !self.discoveredNodes.contains(where: { $0.id == node.id }) {
                self.discoveredNodes.append(node)
            }
        }
    }

    // MARK: - Network

    private func sendPacket(_ packet: [UInt8], to address: String) async throws {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(address), port: NWEndpoint.Port(integerLiteral: Self.artNetPort))

        let connection = NWConnection(to: endpoint, using: .udp)
        connection.start(queue: sendQueue)

        return try await withCheckedThrowingContinuation { continuation in
            connection.send(content: Data(packet), completion: .contentProcessed { error in
                connection.cancel()
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }
}

// MARK: - sACN (E1.31) Protocol

/// Streaming ACN (sACN / E1.31) protocol implementation
/// Multicast-based DMX over IP
@MainActor
public final class SACNDriver: ObservableObject, LightingProtocolDriver {
    // MARK: - Constants

    private static let sacnPort: UInt16 = 5568
    private static let acnPacketIdentifier: [UInt8] = [
        0x41, 0x53, 0x43, 0x2D, 0x45, 0x31, 0x2E, 0x31, 0x37, 0x00, 0x00, 0x00  // "ASC-E1.17\0\0\0"
    ]

    // MARK: - Properties

    public let protocolName = "sACN (E1.31)"
    @Published public private(set) var isConnected = false

    private var universes: [Int: DMXUniverse] = [:]
    private var connections: [Int: NWConnection] = [:]
    private var sequenceNumbers: [Int: UInt8] = [:]
    private let cid: [UInt8]  // Component Identifier (UUID)
    private let sourceName: String

    // MARK: - Initialization

    public init(sourceName: String = "Echoelmusic") {
        self.sourceName = sourceName
        // Generate random CID (UUID)
        self.cid = (0..<16).map { _ in UInt8.random(in: 0...255) }
    }

    // MARK: - Connection

    public func connect() async throws {
        isConnected = true
    }

    public func disconnect() {
        for (_, connection) in connections {
            connection.cancel()
        }
        connections.removeAll()
        isConnected = false
    }

    // MARK: - DMX Transmission

    public func sendDMXUniverse(_ universe: Int, channels: [UInt8]) async throws {
        guard isConnected else { throw SACNError.notConnected }
        guard universe >= 1 && universe <= 63999 else { throw SACNError.invalidUniverse }
        guard channels.count == 512 else { throw SACNError.invalidDataLength }

        // Get or create connection for this universe's multicast group
        let connection = try await getConnection(for: universe)

        // Build E1.31 packet
        let packet = buildSACNPacket(universe: universe, channels: channels)

        // Send packet
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: Data(packet), completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }

        // Store universe state
        var dmxUniverse = universes[universe] ?? DMXUniverse(universeNumber: universe)
        dmxUniverse.channels = channels
        dmxUniverse.timestamp = mach_absolute_time()
        universes[universe] = dmxUniverse
    }

    public func setChannel(_ universe: Int, channel: Int, value: UInt8) async throws {
        var dmxUniverse = universes[universe] ?? DMXUniverse(universeNumber: universe)
        dmxUniverse.setChannel(channel, value: value)
        universes[universe] = dmxUniverse

        try await sendDMXUniverse(universe, channels: dmxUniverse.channels)
    }

    public func getChannelValues(_ universe: Int) -> [UInt8] {
        universes[universe]?.channels ?? [UInt8](repeating: 0, count: 512)
    }

    // MARK: - Packet Building

    private func buildSACNPacket(universe: Int, channels: [UInt8]) -> [UInt8] {
        var packet = [UInt8]()

        // === Root Layer (38 bytes) ===

        // Preamble Size (2 bytes, Big Endian) - 0x0010
        packet.append(0x00)
        packet.append(0x10)

        // Post-amble Size (2 bytes) - 0x0000
        packet.append(0x00)
        packet.append(0x00)

        // ACN Packet Identifier (12 bytes)
        packet.append(contentsOf: Self.acnPacketIdentifier)

        // Flags and Length (2 bytes) - High 4 bits = 0x7, Low 12 bits = length
        let rootLength = 38 + 77 + 523 - 16  // Total - preamble/postamble/identifier
        packet.append(UInt8(0x70 | ((rootLength >> 8) & 0x0F)))
        packet.append(UInt8(rootLength & 0xFF))

        // Vector (4 bytes) - VECTOR_ROOT_E131_DATA = 0x00000004
        packet.append(0x00)
        packet.append(0x00)
        packet.append(0x00)
        packet.append(0x04)

        // CID (16 bytes) - Component Identifier
        packet.append(contentsOf: cid)

        // === Framing Layer (77 bytes) ===

        // Flags and Length
        let framingLength = 77 + 523 - 4
        packet.append(UInt8(0x70 | ((framingLength >> 8) & 0x0F)))
        packet.append(UInt8(framingLength & 0xFF))

        // Vector (4 bytes) - VECTOR_E131_DATA_PACKET = 0x00000002
        packet.append(0x00)
        packet.append(0x00)
        packet.append(0x00)
        packet.append(0x02)

        // Source Name (64 bytes, null-terminated UTF-8)
        var sourceNameBytes = [UInt8](sourceName.utf8)
        sourceNameBytes.append(contentsOf: [UInt8](repeating: 0, count: 64 - sourceNameBytes.count))
        packet.append(contentsOf: sourceNameBytes.prefix(64))

        // Priority (1 byte) - 100 (default)
        packet.append(100)

        // Synchronization Address (2 bytes) - 0 = no sync
        packet.append(0x00)
        packet.append(0x00)

        // Sequence Number (1 byte)
        let seq = (sequenceNumbers[universe] ?? 0) &+ 1
        sequenceNumbers[universe] = seq
        packet.append(seq)

        // Options (1 byte) - 0 = default
        packet.append(0x00)

        // Universe (2 bytes, Big Endian)
        packet.append(UInt8((universe >> 8) & 0xFF))
        packet.append(UInt8(universe & 0xFF))

        // === DMP Layer (523 bytes) ===

        // Flags and Length
        let dmpLength = 523 - 2
        packet.append(UInt8(0x70 | ((dmpLength >> 8) & 0x0F)))
        packet.append(UInt8(dmpLength & 0xFF))

        // Vector (1 byte) - VECTOR_DMP_SET_PROPERTY = 0x02
        packet.append(0x02)

        // Address Type & Data Type (1 byte) - 0xA1
        packet.append(0xA1)

        // First Property Address (2 bytes, Big Endian) - 0x0000
        packet.append(0x00)
        packet.append(0x00)

        // Address Increment (2 bytes, Big Endian) - 0x0001
        packet.append(0x00)
        packet.append(0x01)

        // Property Value Count (2 bytes, Big Endian) - 513 (start code + 512 DMX)
        packet.append(0x02)
        packet.append(0x01)

        // Start Code (1 byte) - 0x00 for DMX
        packet.append(0x00)

        // DMX Data (512 bytes)
        packet.append(contentsOf: channels)

        return packet
    }

    // MARK: - Multicast

    private func getConnection(for universe: Int) async throws -> NWConnection {
        if let existing = connections[universe] {
            return existing
        }

        // sACN uses multicast: 239.255.{universe_high}.{universe_low}
        let multicastAddress = "239.255.\((universe >> 8) & 0xFF).\(universe & 0xFF)"

        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(multicastAddress),
            port: NWEndpoint.Port(integerLiteral: Self.sacnPort)
        )

        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true

        let connection = NWConnection(to: endpoint, using: parameters)
        connection.start(queue: .main)

        connections[universe] = connection
        return connection
    }
}

// MARK: - Errors

public enum ArtNetError: Error {
    case notConnected
    case invalidDataLength
    case sendFailed
}

public enum SACNError: Error {
    case notConnected
    case invalidUniverse
    case invalidDataLength
    case sendFailed
}

// MARK: - Unified Lighting Manager

/// Unified manager for all lighting protocols
@MainActor
public final class UnifiedLightingManager: ObservableObject {
    public static let shared = UnifiedLightingManager()

    @Published public private(set) var activeProtocols: [String] = []

    private let artNet = ArtNetDriver()
    private let sacn = SACNDriver()

    private init() {}

    /// Connect to Art-Net
    public func connectArtNet() async throws {
        try await artNet.connect()
        activeProtocols.append("Art-Net")
    }

    /// Connect to sACN
    public func connectSACN() async throws {
        try await sacn.connect()
        activeProtocols.append("sACN")
    }

    /// Disconnect all protocols
    public func disconnectAll() {
        artNet.disconnect()
        sacn.disconnect()
        activeProtocols.removeAll()
    }

    /// Send DMX via preferred protocol
    public func sendDMX(universe: Int, channels: [UInt8], protocol preferredProtocol: LightingProtocolType = .artNet) async throws {
        switch preferredProtocol {
        case .artNet:
            try await artNet.sendDMXUniverse(universe, channels: channels)
        case .sacn:
            try await sacn.sendDMXUniverse(universe, channels: channels)
        case .both:
            // Send to both for redundancy
            try await artNet.sendDMXUniverse(universe, channels: channels)
            try await sacn.sendDMXUniverse(universe, channels: channels)
        }
    }

    /// Send sync pulse (Art-Net only)
    public func sendSync() async throws {
        try await artNet.sendSync()
    }

    /// Get discovered Art-Net nodes
    public var artNetNodes: [ArtNetDriver.ArtNetNode] {
        artNet.discoveredNodes
    }

    public enum LightingProtocolType {
        case artNet
        case sacn
        case both
    }
}
