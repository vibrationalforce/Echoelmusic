#if canImport(Network)
// DanteTransport.swift — AES67-Compatible Network Audio Transport
// Open standard implementation (RFC 7273) for professional network audio.
// PTP clock sync (IEEE 1588 simplified), RTP audio packets, mDNS discovery.
// No proprietary Dante SDK required — pure Network.framework.
//
// Supports: L16/L24 audio, 44.1k/48k/96k, up to 64 channels
// Discovery: NWBrowser for _aes67._udp Bonjour service
// Transport: UDP multicast (239.x.x.x)

import Foundation
import Network
#if canImport(Observation)
import Observation
#endif

// MARK: - AES67 Stream Configuration

/// Configuration for an AES67 audio stream
public struct AES67StreamConfig: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var sampleRate: Int
    public var bitDepth: Int         // 16 or 24
    public var channelCount: Int     // 1-64
    public var packetTimeMs: Double  // 0.125, 0.25, 0.333, 1.0, 4.0
    public var multicastGroup: String
    public var multicastPort: UInt16

    public init(
        name: String = "Echoelmusic",
        sampleRate: Int = 48000,
        bitDepth: Int = 24,
        channelCount: Int = 2,
        packetTimeMs: Double = 1.0,
        multicastGroup: String = "239.69.1.1",
        multicastPort: UInt16 = 5004
    ) {
        self.id = UUID()
        self.name = name
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.channelCount = channelCount
        self.packetTimeMs = packetTimeMs
        self.multicastGroup = multicastGroup
        self.multicastPort = multicastPort
    }

    /// Samples per packet based on packetTime and sampleRate
    public var samplesPerPacket: Int {
        max(1, Int(Double(sampleRate) * packetTimeMs / 1000.0))
    }

    /// Bytes per sample (bitDepth / 8)
    public var bytesPerSample: Int {
        bitDepth / 8
    }

    /// Total payload bytes per packet
    public var payloadSize: Int {
        samplesPerPacket * channelCount * bytesPerSample
    }
}

// MARK: - Discovered Device

/// A discovered AES67/Dante device on the network
public struct AES67Device: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var address: String
    public var port: UInt16
    public var channelCount: Int
    public var sampleRate: Int
    public var lastSeen: Date
}

// MARK: - PTP Clock (IEEE 1588 Simplified)

/// Simplified PTP clock for AES67 synchronization.
/// Tracks offset to a master clock via delay request/response pairs.
public final class PTPClock: @unchecked Sendable {
    private var masterOffset: TimeInterval = 0
    private var samples: [(offset: TimeInterval, delay: TimeInterval)] = []
    private let maxSamples = 20

    /// Current estimated offset from master (seconds)
    public var offset: TimeInterval { masterOffset }

    /// Synchronized time = local time + offset
    public var synchronizedTime: TimeInterval {
        CFAbsoluteTimeGetCurrent() + masterOffset
    }

    /// Process a sync response from the PTP master
    public func processSyncResponse(t1: TimeInterval, t2: TimeInterval, t3: TimeInterval, t4: TimeInterval) {
        let offset = ((t2 - t1) + (t3 - t4)) / 2.0
        let delay = ((t4 - t1) - (t3 - t2)) / 2.0

        samples.append((offset: offset, delay: delay))
        if samples.count > maxSamples { samples.removeFirst() }

        // Weighted average — lower delay samples are more accurate
        guard !samples.isEmpty else { return }
        let minDelay = samples.map(\.delay).min() ?? 0
        let threshold = minDelay * 3.0
        let filtered = samples.filter { $0.delay <= threshold }
        guard !filtered.isEmpty else { return }

        masterOffset = filtered.map(\.offset).reduce(0, +) / Double(filtered.count)
    }
}

// MARK: - Jitter Buffer

/// Reordering jitter buffer for RTP packets.
/// Holds packets until they can be released in sequence order.
public final class JitterBuffer: @unchecked Sendable {
    private var buffer: [(seq: UInt16, data: Data)] = []
    private var nextExpectedSeq: UInt16 = 0
    private let maxDepth: Int

    /// Packet loss counter
    public private(set) var packetsLost: UInt64 = 0

    /// Current buffer depth (packets waiting)
    public var depth: Int { buffer.count }

    public init(maxDepth: Int = 10) {
        self.maxDepth = maxDepth
    }

    /// Insert a packet into the buffer
    public func insert(sequenceNumber: UInt16, data: Data) {
        buffer.append((seq: sequenceNumber, data: data))
        buffer.sort { $0.seq < $1.seq }

        // Drop excess
        while buffer.count > maxDepth {
            buffer.removeFirst()
            packetsLost += 1
        }
    }

    /// Retrieve the next packet in sequence, or nil if not yet available
    public func dequeue() -> Data? {
        guard let first = buffer.first else { return nil }

        // If the expected sequence is here (or we've fallen behind), release it
        let seqDiff = Int(first.seq) - Int(nextExpectedSeq)
        if seqDiff <= 0 || seqDiff > 1000 {
            // Packet is on time or late — release
            buffer.removeFirst()
            nextExpectedSeq = first.seq &+ 1
            return first.data
        }

        return nil  // Waiting for earlier packet
    }

    /// Reset the buffer
    public func reset() {
        buffer.removeAll()
        nextExpectedSeq = 0
    }
}

// MARK: - RTP Header

/// RTP header construction for AES67 audio packets
private struct RTPHeader {
    static let headerSize = 12

    static func encode(
        sequenceNumber: UInt16,
        timestamp: UInt32,
        ssrc: UInt32,
        payloadType: UInt8 = 96  // Dynamic payload type for L24
    ) -> Data {
        var data = Data(count: headerSize)
        // V=2, P=0, X=0, CC=0
        data[0] = 0x80
        // M=0, PT
        data[1] = payloadType
        // Sequence number (big-endian)
        data[2] = UInt8(sequenceNumber >> 8)
        data[3] = UInt8(sequenceNumber & 0xFF)
        // Timestamp (big-endian)
        data[4] = UInt8((timestamp >> 24) & 0xFF)
        data[5] = UInt8((timestamp >> 16) & 0xFF)
        data[6] = UInt8((timestamp >> 8) & 0xFF)
        data[7] = UInt8(timestamp & 0xFF)
        // SSRC (big-endian)
        data[8] = UInt8((ssrc >> 24) & 0xFF)
        data[9] = UInt8((ssrc >> 16) & 0xFF)
        data[10] = UInt8((ssrc >> 8) & 0xFF)
        data[11] = UInt8(ssrc & 0xFF)
        return data
    }

    static func decode(_ data: Data) -> (seq: UInt16, timestamp: UInt32, ssrc: UInt32)? {
        guard data.count >= headerSize else { return nil }
        let seq = UInt16(data[2]) << 8 | UInt16(data[3])
        let ts = UInt32(data[4]) << 24 | UInt32(data[5]) << 16 | UInt32(data[6]) << 8 | UInt32(data[7])
        let ssrc = UInt32(data[8]) << 24 | UInt32(data[9]) << 16 | UInt32(data[10]) << 8 | UInt32(data[11])
        return (seq, ts, ssrc)
    }
}

// MARK: - DanteTransport

/// AES67-compatible network audio transport using Network.framework.
/// Sends and receives professional audio over UDP multicast.
@preconcurrency @MainActor
@Observable
public final class DanteTransport {

    @MainActor public static let shared = DanteTransport()

    // MARK: - State

    /// Whether the transport is actively sending
    public var isSending: Bool = false

    /// Whether the transport is actively receiving
    public var isReceiving: Bool = false

    /// Current stream configuration
    public var config: AES67StreamConfig = AES67StreamConfig()

    /// Discovered AES67 devices
    public var discoveredDevices: [AES67Device] = []

    /// PTP clock for synchronization
    public let ptpClock = PTPClock()

    /// Statistics
    public var packetsSent: UInt64 = 0
    public var packetsReceived: UInt64 = 0
    public var packetLoss: UInt64 = 0
    public var jitterMs: Double = 0.0
    public var clockOffsetUs: Double = 0.0

    // MARK: - Private

    private var sendConnection: NWConnection?
    private var receiveConnection: NWConnection?
    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.echoelmusic.dante", qos: .userInteractive)
    private var sequenceNumber: UInt16 = 0
    private var rtpTimestamp: UInt32 = 0
    private let ssrc: UInt32 = UInt32.random(in: 0...UInt32.max)
    private let jitterBuffer = JitterBuffer(maxDepth: 10)
    nonisolated(unsafe) private var sendTimer: Timer?

    /// Callback for received audio samples
    public var onAudioReceived: (([Float], Int) -> Void)?  // samples, channelCount

    // MARK: - Init

    private init() {
        log.log(.info, category: .audio, "DanteTransport initialized — AES67 compatible")
    }

    deinit {
        sendTimer?.invalidate()
    }

    // MARK: - Discovery

    /// Start browsing for AES67 devices via mDNS
    public func startDiscovery() {
        let browser = NWBrowser(for: .bonjour(type: "_aes67._udp", domain: nil), using: .udp)

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                for result in results {
                    if case .service(let name, _, _, _) = result.endpoint {
                        guard !self.discoveredDevices.contains(where: { $0.name == name }) else { continue }
                        let device = AES67Device(
                            id: UUID(),
                            name: name,
                            address: result.endpoint.debugDescription,
                            port: 5004,
                            channelCount: 2,
                            sampleRate: 48000,
                            lastSeen: Date()
                        )
                        self.discoveredDevices.append(device)
                        log.log(.info, category: .audio, "AES67 device discovered: \(name)")
                    }
                }
            }
        }

        browser.start(queue: queue)
        self.browser = browser
    }

    /// Stop discovery
    public func stopDiscovery() {
        browser?.cancel()
        browser = nil
    }

    // MARK: - Send

    /// Start sending audio via RTP multicast
    public func startSending() {
        guard !isSending else { return }

        let host = NWEndpoint.Host(config.multicastGroup)
        let port = NWEndpoint.Port(rawValue: config.multicastPort) ?? 5004
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true

        let connection = NWConnection(host: host, port: port, using: params)
        connection.start(queue: queue)
        self.sendConnection = connection
        isSending = true
        sequenceNumber = 0
        rtpTimestamp = 0

        log.log(.info, category: .audio, "DanteTransport sending to \(config.multicastGroup):\(config.multicastPort)")
    }

    /// Send a block of audio samples as RTP packet(s)
    /// - Parameters:
    ///   - samples: Interleaved float samples
    ///   - channelCount: Number of channels in the interleaved data
    public func sendAudio(samples: [Float], channelCount: Int) {
        guard isSending, let connection = sendConnection else { return }

        let samplesPerChannel = samples.count / max(1, channelCount)
        let bytesPerSample = config.bytesPerSample

        // Convert float samples to L24 or L16 (big-endian, two's complement)
        var payload = Data(capacity: samples.count * bytesPerSample)

        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))

            if bytesPerSample == 3 {
                // L24: scale to 24-bit signed
                let scaled = Int32(clamped * Float(0x7FFFFF))
                payload.append(UInt8((scaled >> 16) & 0xFF))
                payload.append(UInt8((scaled >> 8) & 0xFF))
                payload.append(UInt8(scaled & 0xFF))
            } else {
                // L16: scale to 16-bit signed
                let scaled = Int16(clamped * Float(Int16.max))
                payload.append(UInt8(UInt16(bitPattern: scaled) >> 8))
                payload.append(UInt8(UInt16(bitPattern: scaled) & 0xFF))
            }
        }

        // Build RTP packet
        let header = RTPHeader.encode(
            sequenceNumber: sequenceNumber,
            timestamp: rtpTimestamp,
            ssrc: ssrc
        )

        var packet = header
        packet.append(payload)

        connection.send(content: packet, completion: .contentProcessed { [weak self] error in
            if let error {
                log.log(.error, category: .audio, "DanteTransport send error: \(error)")
            }
        })

        sequenceNumber &+= 1
        rtpTimestamp &+= UInt32(samplesPerChannel)
        packetsSent += 1
    }

    /// Stop sending
    public func stopSending() {
        guard isSending else { return }
        sendConnection?.cancel()
        sendConnection = nil
        sendTimer?.invalidate()
        sendTimer = nil
        isSending = false
        log.log(.info, category: .audio, "DanteTransport stopped sending")
    }

    // MARK: - Receive

    /// Start receiving audio from multicast group
    public func startReceiving() {
        guard !isReceiving else { return }

        let host = NWEndpoint.Host(config.multicastGroup)
        let port = NWEndpoint.Port(rawValue: config.multicastPort) ?? 5004
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true

        let connection = NWConnection(host: host, port: port, using: params)

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if case .ready = state {
                    self.isReceiving = true
                    log.log(.info, category: .audio, "DanteTransport receiving from \(self.config.multicastGroup)")
                }
            }
        }

        connection.start(queue: queue)
        self.receiveConnection = connection
        receivePacket(on: connection)
    }

    private func receivePacket(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: RTPHeader.headerSize, maximumLength: 65535) { [weak self] data, _, _, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let data, data.count > RTPHeader.headerSize {
                    self.processReceivedPacket(data)
                }

                if error == nil {
                    self.receivePacket(on: connection)
                }
            }
        }
    }

    private func processReceivedPacket(_ data: Data) {
        guard let header = RTPHeader.decode(data) else { return }

        let payload = data.subdata(in: RTPHeader.headerSize..<data.count)

        // Insert into jitter buffer
        jitterBuffer.insert(sequenceNumber: header.seq, data: payload)
        packetsReceived += 1
        packetLoss = jitterBuffer.packetsLost

        // Dequeue in order and decode
        while let orderedPayload = jitterBuffer.dequeue() {
            let samples = decodeAudioPayload(orderedPayload)
            onAudioReceived?(samples, config.channelCount)
        }
    }

    private func decodeAudioPayload(_ data: Data) -> [Float] {
        let bytesPerSample = config.bytesPerSample
        let sampleCount = data.count / bytesPerSample
        var samples = [Float](repeating: 0, count: sampleCount)

        for i in 0..<sampleCount {
            let offset = i * bytesPerSample

            if bytesPerSample == 3 && offset + 2 < data.count {
                // L24 big-endian
                let b0 = Int32(data[offset]) << 16
                let b1 = Int32(data[offset + 1]) << 8
                let b2 = Int32(data[offset + 2])
                var value = b0 | b1 | b2
                // Sign extend from 24-bit
                if value & 0x800000 != 0 { value |= Int32(bitPattern: 0xFF000000) }
                samples[i] = Float(value) / Float(0x7FFFFF)
            } else if bytesPerSample == 2 && offset + 1 < data.count {
                // L16 big-endian
                let value = Int16(data[offset]) << 8 | Int16(data[offset + 1])
                samples[i] = Float(value) / Float(Int16.max)
            }
        }

        return samples
    }

    /// Stop receiving
    public func stopReceiving() {
        guard isReceiving else { return }
        receiveConnection?.cancel()
        receiveConnection = nil
        jitterBuffer.reset()
        isReceiving = false
        log.log(.info, category: .audio, "DanteTransport stopped receiving")
    }

    // MARK: - SAP Advertisement

    /// Advertise this stream via SAP (Session Announcement Protocol)
    /// SAP packets are sent to 224.2.127.254:9875 per RFC 2974
    public func advertiseSAP() {
        let sdp = """
        v=0
        o=- \(ssrc) 1 IN IP4 0.0.0.0
        s=\(config.name)
        c=IN IP4 \(config.multicastGroup)/32
        t=0 0
        m=audio \(config.multicastPort) RTP/AVP 96
        a=rtpmap:96 L\(config.bitDepth)/\(config.sampleRate)/\(config.channelCount)
        a=ptime:\(config.packetTimeMs)
        a=recvonly
        """

        guard let sdpData = sdp.data(using: .utf8) else { return }

        // SAP header (version 1, no auth, no encryption)
        var sapPacket = Data()
        sapPacket.append(0x20)  // V=1, A=0, R=0, T=0, L=0
        sapPacket.append(0x00)  // Auth length = 0
        sapPacket.append(contentsOf: withUnsafeBytes(of: UInt16(0).bigEndian) { Array($0) })  // Message ID hash
        sapPacket.append(contentsOf: [0, 0, 0, 0])  // Origin source (0.0.0.0)
        // Content type
        if let ct = "application/sdp\0".data(using: .utf8) {
            sapPacket.append(ct)
        }
        sapPacket.append(sdpData)

        let host = NWEndpoint.Host("224.2.127.254")
        let port = NWEndpoint.Port(rawValue: 9875)!
        let connection = NWConnection(host: host, port: port, using: .udp)
        connection.start(queue: queue)
        connection.send(content: sapPacket, completion: .contentProcessed { _ in
            connection.cancel()
        })

        log.log(.info, category: .audio, "DanteTransport SAP advertisement sent")
    }
}

#endif // canImport(Network)
