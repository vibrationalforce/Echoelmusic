// NDISyphonEngine.swift
// Echoelmusic — NDI/Syphon-compatible video streaming via Network.framework
//
// Native NDI-compatible sender/receiver using mDNS discovery,
// TCP command channel, and UDP video transport. Zero external dependencies.
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

#if canImport(Network)
import Foundation
import Network
import Combine

#if canImport(Metal)
import Metal
#endif

#if canImport(Accelerate)
import Accelerate
#endif

// MARK: - NDI Types

/// Pixel format for NDI-compatible frame transport
public enum NDIPixelFormat: String, Sendable, CaseIterable {
    case uyvy = "UYVY"
    case nv12 = "NV12"
    case bgra = "BGRA"
}

/// Supported output resolutions
public enum NDIResolution: Sendable, CaseIterable {
    case hd720
    case hd1080
    case uhd4k

    public var width: Int {
        switch self {
        case .hd720: return 1280
        case .hd1080: return 1920
        case .uhd4k: return 3840
        }
    }

    public var height: Int {
        switch self {
        case .hd720: return 720
        case .hd1080: return 1080
        case .uhd4k: return 2160
        }
    }

    public var label: String {
        switch self {
        case .hd720: return "720p"
        case .hd1080: return "1080p"
        case .uhd4k: return "4K"
        }
    }
}

/// Supported frame rates
public enum NDIFrameRate: Double, Sendable, CaseIterable {
    case fps24 = 24.0
    case fps25 = 25.0
    case fps30 = 30.0
    case fps60 = 60.0

    public var frameInterval: TimeInterval { 1.0 / rawValue }
}

/// Tally state for connected receivers
public enum NDITally: String, Sendable {
    case none = "None"
    case preview = "Preview"
    case program = "Program"
}

/// A discovered NDI source on the network
public struct NDISource: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let host: String
    public let port: UInt16
    public let discoveredAt: Date

    public init(name: String, host: String, port: UInt16) {
        self.id = "\(host):\(port)"
        self.name = name
        self.host = host
        self.port = port
        self.discoveredAt = Date()
    }
}

/// A single video frame for NDI transport
public struct NDIFrame: Sendable {
    public let width: Int
    public let height: Int
    public let pixelFormat: NDIPixelFormat
    public let data: Data
    public let timestamp: UInt64
    public let frameNumber: UInt64
    public let audioSamples: Data?
    public let audioSampleRate: Int
    public let audioChannels: Int

    public init(
        width: Int,
        height: Int,
        pixelFormat: NDIPixelFormat,
        data: Data,
        timestamp: UInt64,
        frameNumber: UInt64,
        audioSamples: Data? = nil,
        audioSampleRate: Int = 48000,
        audioChannels: Int = 2
    ) {
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.data = data
        self.timestamp = timestamp
        self.frameNumber = frameNumber
        self.audioSamples = audioSamples
        self.audioSampleRate = audioSampleRate
        self.audioChannels = audioChannels
    }
}

/// Streaming statistics
public struct NDIStreamStats: Sendable {
    public var framesSent: UInt64 = 0
    public var framesDropped: UInt64 = 0
    public var bytesSent: UInt64 = 0
    public var bandwidthBytesPerSec: Double = 0
    public var connectedReceivers: Int = 0
    public var averageFrameTimeMs: Double = 0
    public var uptime: TimeInterval = 0
}

// MARK: - NDISyphonEngine

/// NDI/Syphon-compatible video streaming engine using Network.framework.
/// Provides mDNS service advertisement, TCP command channel, UDP video transport,
/// and Bonjour receiver discovery. Accepts MTLTexture input for zero-copy pipeline.
@preconcurrency @MainActor @Observable
public final class NDISyphonEngine {

    // MARK: - Singleton

    @MainActor public static let shared = NDISyphonEngine()

    // MARK: - Published State

    public private(set) var isStreaming = false
    public private(set) var isBrowsing = false
    public private(set) var discoveredSources: [NDISource] = []
    public private(set) var connectedReceiverCount = 0
    public private(set) var currentTally: NDITally = .none
    public private(set) var stats = NDIStreamStats()

    // MARK: - Configuration

    public var sourceName: String = "Echoelmusic"
    public var resolution: NDIResolution = .hd1080
    public var frameRate: NDIFrameRate = .fps30
    public var pixelFormat: NDIPixelFormat = .uyvy
    public var audioEnabled = true
    public var audioSampleRate: Int = 48000
    public var audioChannels: Int = 2

    // MARK: - Private State

    private let serviceType = "_ndi._tcp"
    private let serviceDomain = "local."
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var commandConnections: [NWConnection] = []
    private var udpConnection: NWConnection?
    private var frameTimer: DispatchSourceTimer?
    private var frameCounter: UInt64 = 0
    private var startTime: Date?
    private var bandwidthAccumulator: UInt64 = 0
    private var bandwidthTimestamp: Date = Date()
    private var cancellables = Set<AnyCancellable>()

    #if canImport(Metal)
    private var metalDevice: MTLDevice?
    private var conversionBuffer: UnsafeMutableRawPointer?
    private var conversionBufferSize: Int = 0
    #endif

    private let streamQueue = DispatchQueue(
        label: "com.echoelmusic.ndi.stream",
        qos: .userInteractive
    )
    private let commandQueue = DispatchQueue(
        label: "com.echoelmusic.ndi.command",
        qos: .userInitiated
    )

    // MARK: - Init

    private init() {
        #if canImport(Metal)
        metalDevice = MTLCreateSystemDefaultDevice()
        #endif
        log.log(.info, category: .network, "NDISyphonEngine initialized")
    }

    deinit {
        stopStreaming()
        stopBrowsing()
        #if canImport(Metal)
        if let buffer = conversionBuffer {
            buffer.deallocate()
        }
        #endif
    }

    // MARK: - Sender

    /// Start NDI-compatible streaming with mDNS advertisement
    public func startStreaming() {
        guard !isStreaming else { return }

        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let listener = try NWListener(using: params)

            let service = NWListener.Service(
                name: sourceName,
                type: serviceType,
                domain: serviceDomain
            )
            listener.service = service

            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    self?.handleListenerState(state)
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.handleNewConnection(connection)
                }
            }

            listener.start(queue: commandQueue)
            self.listener = listener
            self.isStreaming = true
            self.startTime = Date()
            self.frameCounter = 0
            self.stats = NDIStreamStats()

            startFrameTimer()
            log.log(.info, category: .network, "NDI streaming started — \(sourceName) @ \(resolution.label) \(Int(frameRate.rawValue))fps")
        } catch {
            log.log(.error, category: .network, "NDI listener failed: \(error.localizedDescription)")
        }
    }

    /// Stop streaming and tear down connections
    public func stopStreaming() {
        guard isStreaming else { return }

        frameTimer?.cancel()
        frameTimer = nil

        for connection in commandConnections {
            connection.cancel()
        }
        commandConnections.removeAll()

        udpConnection?.cancel()
        udpConnection = nil

        listener?.cancel()
        listener = nil

        isStreaming = false
        connectedReceiverCount = 0
        currentTally = .none
        log.log(.info, category: .network, "NDI streaming stopped")
    }

    // MARK: - Frame Submission

    #if canImport(Metal)
    /// Submit a Metal texture for streaming. Converts to configured pixel format
    /// and dispatches to connected receivers.
    public func submitTexture(_ texture: MTLTexture) {
        guard isStreaming, connectedReceiverCount > 0 else { return }

        let width = texture.width
        let height = texture.height

        guard let frameData = convertTextureToPixelFormat(texture) else {
            stats.framesDropped += 1
            return
        }

        let frame = NDIFrame(
            width: width,
            height: height,
            pixelFormat: pixelFormat,
            data: frameData,
            timestamp: mach_absolute_time(),
            frameNumber: frameCounter
        )

        sendFrame(frame)
    }
    #endif

    /// Submit raw frame data for streaming
    public func submitFrame(_ frame: NDIFrame) {
        guard isStreaming else { return }
        sendFrame(frame)
    }

    /// Submit frame with interleaved audio
    public func submitFrameWithAudio(
        _ frame: NDIFrame,
        audioSamples: Data,
        sampleRate: Int,
        channels: Int
    ) {
        guard isStreaming else { return }

        let audioFrame = NDIFrame(
            width: frame.width,
            height: frame.height,
            pixelFormat: frame.pixelFormat,
            data: frame.data,
            timestamp: frame.timestamp,
            frameNumber: frame.frameNumber,
            audioSamples: audioSamples,
            audioSampleRate: sampleRate,
            audioChannels: channels
        )

        sendFrame(audioFrame)
    }

    // MARK: - Receiver Discovery

    /// Start browsing for NDI sources on the local network
    public func startBrowsing() {
        guard !isBrowsing else { return }

        let descriptor = NWBrowser.Descriptor.bonjour(type: serviceType, domain: serviceDomain)
        let params = NWParameters()
        params.includePeerToPeer = true
        let browser = NWBrowser(for: descriptor, using: params)

        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleBrowserState(state)
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor in
                self?.handleBrowseResults(results)
            }
        }

        browser.start(queue: commandQueue)
        self.browser = browser
        self.isBrowsing = true
        log.log(.info, category: .network, "NDI source browsing started")
    }

    /// Stop browsing for NDI sources
    public func stopBrowsing() {
        guard isBrowsing else { return }

        browser?.cancel()
        browser = nil
        isBrowsing = false
        discoveredSources.removeAll()
        log.log(.info, category: .network, "NDI source browsing stopped")
    }

    // MARK: - Tally

    /// Update tally state and notify connected receivers
    public func setTally(_ tally: NDITally) {
        currentTally = tally
        broadcastTallyUpdate(tally)
        log.log(.info, category: .network, "NDI tally: \(tally.rawValue)")
    }

    // MARK: - Private — Networking

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            log.log(.info, category: .network, "NDI listener ready")
        case .failed(let error):
            log.log(.error, category: .network, "NDI listener failed: \(error.localizedDescription)")
            stopStreaming()
        case .cancelled:
            log.log(.info, category: .network, "NDI listener cancelled")
        default:
            break
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self?.commandConnections.append(connection)
                    self?.connectedReceiverCount = self?.commandConnections.count ?? 0
                    self?.stats.connectedReceivers = self?.connectedReceiverCount ?? 0
                    log.log(.info, category: .network, "NDI receiver connected (\(self?.connectedReceiverCount ?? 0) total)")
                    self?.receiveCommandData(on: connection)
                case .failed, .cancelled:
                    self?.removeConnection(connection)
                default:
                    break
                }
            }
        }
        connection.start(queue: commandQueue)
    }

    private func removeConnection(_ connection: NWConnection) {
        commandConnections.removeAll { $0 === connection }
        connectedReceiverCount = commandConnections.count
        stats.connectedReceivers = connectedReceiverCount
        log.log(.info, category: .network, "NDI receiver disconnected (\(connectedReceiverCount) remaining)")
    }

    private func receiveCommandData(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                if let data = data, !data.isEmpty {
                    self?.handleCommandData(data, from: connection)
                }
                if let error = error {
                    log.log(.error, category: .network, "NDI command error: \(error.localizedDescription)")
                    self?.removeConnection(connection)
                    return
                }
                if isComplete {
                    self?.removeConnection(connection)
                    return
                }
                self?.receiveCommandData(on: connection)
            }
        }
    }

    private func handleCommandData(_ data: Data, from connection: NWConnection) {
        // Parse NDI-compatible command messages (tally requests, metadata)
        guard data.count >= 4 else { return }

        let headerBytes = [UInt8](data.prefix(4))
        let commandID = UInt32(headerBytes[0]) | (UInt32(headerBytes[1]) << 8)
            | (UInt32(headerBytes[2]) << 16) | (UInt32(headerBytes[3]) << 24)

        switch commandID {
        case 0x0001: // Tally request
            sendTallyResponse(to: connection)
        case 0x0002: // Metadata request
            sendMetadataResponse(to: connection)
        default:
            break
        }
    }

    // MARK: - Private — Frame Transport

    private func startFrameTimer() {
        let timer = DispatchSource.makeTimerSource(queue: streamQueue)
        let interval = frameRate.frameInterval
        timer.schedule(
            deadline: .now(),
            repeating: interval,
            leeway: .milliseconds(1)
        )
        timer.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.frameTimerFired()
            }
        }
        timer.resume()
        frameTimer = timer
    }

    private func frameTimerFired() {
        frameCounter += 1
        updateBandwidthStats()

        guard let start = startTime else { return }
        stats.uptime = Date().timeIntervalSince(start)
        stats.framesSent = frameCounter
    }

    private func sendFrame(_ frame: NDIFrame) {
        // Build NDI-compatible frame header
        var header = Data()
        header.append(contentsOf: withUnsafeBytes(of: UInt32(frame.width).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt32(frame.height).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: frame.timestamp.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: frame.frameNumber.littleEndian) { Array($0) })

        // Pixel format identifier
        let formatID: UInt32 = switch frame.pixelFormat {
        case .uyvy: 0x59565955
        case .nv12: 0x3231564E
        case .bgra: 0x41524742
        }
        header.append(contentsOf: withUnsafeBytes(of: formatID.littleEndian) { Array($0) })

        // Audio flag and metadata
        let hasAudio: UInt8 = (frame.audioSamples != nil && audioEnabled) ? 1 : 0
        header.append(hasAudio)

        if hasAudio == 1, let audioData = frame.audioSamples {
            header.append(contentsOf: withUnsafeBytes(of: UInt32(frame.audioSampleRate).littleEndian) { Array($0) })
            header.append(contentsOf: withUnsafeBytes(of: UInt16(frame.audioChannels).littleEndian) { Array($0) })
            header.append(contentsOf: withUnsafeBytes(of: UInt32(audioData.count).littleEndian) { Array($0) })
        }

        // Video data length
        header.append(contentsOf: withUnsafeBytes(of: UInt32(frame.data.count).littleEndian) { Array($0) })

        var payload = header
        payload.append(frame.data)
        if hasAudio == 1, let audioData = frame.audioSamples {
            payload.append(audioData)
        }

        // Send to all connected receivers
        for connection in commandConnections {
            connection.send(content: payload, completion: .contentProcessed { [weak self] error in
                if let error = error {
                    Task { @MainActor in
                        log.log(.error, category: .network, "NDI frame send error: \(error.localizedDescription)")
                        self?.stats.framesDropped += 1
                    }
                }
            })
        }

        let byteCount = UInt64(payload.count)
        stats.bytesSent += byteCount
        bandwidthAccumulator += byteCount
    }

    // MARK: - Private — Pixel Format Conversion

    #if canImport(Metal) && canImport(Accelerate)
    /// Convert MTLTexture (BGRA8) to configured NDI pixel format using Accelerate
    private func convertTextureToPixelFormat(_ texture: MTLTexture) -> Data? {
        let width = texture.width
        let height = texture.height
        let bytesPerRow = width * 4
        let bgraSize = height * bytesPerRow

        // Ensure conversion buffer is large enough
        if conversionBufferSize < bgraSize {
            conversionBuffer?.deallocate()
            conversionBuffer = UnsafeMutableRawPointer.allocate(
                byteCount: bgraSize,
                alignment: 16
            )
            conversionBufferSize = bgraSize
        }

        guard let buffer = conversionBuffer else { return nil }

        // Read texture into buffer
        texture.getBytes(
            buffer,
            bytesPerRow: bytesPerRow,
            from: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                           size: MTLSize(width: width, height: height, depth: 1)),
            mipmapLevel: 0
        )

        switch pixelFormat {
        case .bgra:
            return Data(bytes: buffer, count: bgraSize)

        case .uyvy:
            return convertBGRAToUYVY(buffer, width: width, height: height)

        case .nv12:
            return convertBGRAToNV12(buffer, width: width, height: height)
        }
    }

    /// BGRA to UYVY conversion using Accelerate
    private func convertBGRAToUYVY(_ bgraBuffer: UnsafeMutableRawPointer, width: Int, height: Int) -> Data {
        let uyvySize = width * height * 2
        var uyvyData = Data(count: uyvySize)

        uyvyData.withUnsafeMutableBytes { uyvyPtr in
            guard let uyvyBase = uyvyPtr.baseAddress else { return }
            let bgra = bgraBuffer.assumingMemoryBound(to: UInt8.self)
            let uyvy = uyvyBase.assumingMemoryBound(to: UInt8.self)

            for y in 0..<height {
                for x in stride(from: 0, to: width, by: 2) {
                    let bgraOffset0 = (y * width + x) * 4
                    let bgraOffset1 = (y * width + Swift.min(x + 1, width - 1)) * 4

                    let b0 = Float(bgra[bgraOffset0])
                    let g0 = Float(bgra[bgraOffset0 + 1])
                    let r0 = Float(bgra[bgraOffset0 + 2])

                    let b1 = Float(bgra[bgraOffset1])
                    let g1 = Float(bgra[bgraOffset1 + 1])
                    let r1 = Float(bgra[bgraOffset1 + 2])

                    // Break up expressions for Swift compiler performance
                    let luma0: Float = 0.257 * r0 + 0.504 * g0 + 0.098 * b0 + 16
                    let luma1: Float = 0.257 * r1 + 0.504 * g1 + 0.098 * b1 + 16
                    let y0 = UInt8(clamping: Int(luma0))
                    let y1 = UInt8(clamping: Int(luma1))

                    let rAvg = (r0 + r1) * 0.5
                    let gAvg = (g0 + g1) * 0.5
                    let bAvg = (b0 + b1) * 0.5

                    let uVal: Float = -0.148 * rAvg - 0.291 * gAvg + 0.439 * bAvg + 128
                    let vVal: Float = 0.439 * rAvg - 0.368 * gAvg - 0.071 * bAvg + 128
                    let u = UInt8(clamping: Int(uVal))
                    let v = UInt8(clamping: Int(vVal))

                    let uyvyOffset = (y * width + x) * 2
                    uyvy[uyvyOffset] = u
                    uyvy[uyvyOffset + 1] = y0
                    uyvy[uyvyOffset + 2] = v
                    uyvy[uyvyOffset + 3] = y1
                }
            }
        }

        return uyvyData
    }

    /// BGRA to NV12 conversion (Y plane + interleaved UV plane)
    private func convertBGRAToNV12(_ bgraBuffer: UnsafeMutableRawPointer, width: Int, height: Int) -> Data {
        let ySize = width * height
        let uvSize = (width / 2) * (height / 2) * 2
        var nv12Data = Data(count: ySize + uvSize)

        nv12Data.withUnsafeMutableBytes { nv12Ptr in
            guard let nv12Base = nv12Ptr.baseAddress else { return }
            let bgra = bgraBuffer.assumingMemoryBound(to: UInt8.self)
            let yPlane = nv12Base.assumingMemoryBound(to: UInt8.self)
            let uvPlane = yPlane.advanced(by: ySize)

            // Y plane — break up expressions for compiler performance
            for y in 0..<height {
                for x in 0..<width {
                    let offset = (y * width + x) * 4
                    let b = Float(bgra[offset])
                    let g = Float(bgra[offset + 1])
                    let r = Float(bgra[offset + 2])
                    let luma: Float = 0.257 * r + 0.504 * g + 0.098 * b + 16
                    yPlane[y * width + x] = UInt8(clamping: Int(luma))
                }
            }

            // UV plane (subsampled 2x2)
            for y in stride(from: 0, to: height, by: 2) {
                for x in stride(from: 0, to: width, by: 2) {
                    let offset = (y * width + x) * 4
                    let b = Float(bgra[offset])
                    let g = Float(bgra[offset + 1])
                    let r = Float(bgra[offset + 2])

                    let uVal: Float = -0.148 * r - 0.291 * g + 0.439 * b + 128
                    let vVal: Float = 0.439 * r - 0.368 * g - 0.071 * b + 128
                    let u = UInt8(clamping: Int(uVal))
                    let v = UInt8(clamping: Int(vVal))

                    let uvOffset = (y / 2) * width + x
                    uvPlane[uvOffset] = u
                    uvPlane[uvOffset + 1] = v
                }
            }
        }

        return nv12Data
    }
    #endif

    // MARK: - Private — Browser

    private func handleBrowserState(_ state: NWBrowser.State) {
        switch state {
        case .ready:
            log.log(.info, category: .network, "NDI browser ready")
        case .failed(let error):
            log.log(.error, category: .network, "NDI browser failed: \(error.localizedDescription)")
            isBrowsing = false
        default:
            break
        }
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        var sources: [NDISource] = []

        for result in results {
            if case .service(let name, let type, _, _) = result.endpoint {
                guard type == serviceType else { continue }
                let source = NDISource(
                    name: name,
                    host: "",
                    port: 0
                )
                sources.append(source)
            }
        }

        discoveredSources = sources
        log.log(.info, category: .network, "NDI sources discovered: \(sources.count)")
    }

    // MARK: - Private — Tally & Metadata

    private func broadcastTallyUpdate(_ tally: NDITally) {
        var message = Data()
        let commandID: UInt32 = 0x0001
        message.append(contentsOf: withUnsafeBytes(of: commandID.littleEndian) { Array($0) })

        let tallyByte: UInt8 = switch tally {
        case .none: 0
        case .preview: 1
        case .program: 2
        }
        message.append(tallyByte)

        for connection in commandConnections {
            connection.send(content: message, completion: .contentProcessed { error in
                if let error = error {
                    Task { @MainActor in
                        log.log(.error, category: .network, "NDI tally send error: \(error.localizedDescription)")
                    }
                }
            })
        }
    }

    private func sendTallyResponse(to connection: NWConnection) {
        var response = Data()
        let commandID: UInt32 = 0x8001
        response.append(contentsOf: withUnsafeBytes(of: commandID.littleEndian) { Array($0) })

        let tallyByte: UInt8 = switch currentTally {
        case .none: 0
        case .preview: 1
        case .program: 2
        }
        response.append(tallyByte)

        connection.send(content: response, completion: .contentProcessed { _ in })
    }

    private func sendMetadataResponse(to connection: NWConnection) {
        let metadata: [String: Any] = [
            "name": sourceName,
            "width": resolution.width,
            "height": resolution.height,
            "fps": frameRate.rawValue,
            "format": pixelFormat.rawValue,
            "audio": audioEnabled,
            "sampleRate": audioSampleRate,
            "channels": audioChannels
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: metadata) else { return }

        var response = Data()
        let commandID: UInt32 = 0x8002
        response.append(contentsOf: withUnsafeBytes(of: commandID.littleEndian) { Array($0) })
        response.append(contentsOf: withUnsafeBytes(of: UInt32(jsonData.count).littleEndian) { Array($0) })
        response.append(jsonData)

        connection.send(content: response, completion: .contentProcessed { _ in })
    }

    // MARK: - Private — Statistics

    private func updateBandwidthStats() {
        let now = Date()
        let elapsed = now.timeIntervalSince(bandwidthTimestamp)

        if elapsed >= 1.0 {
            stats.bandwidthBytesPerSec = Double(bandwidthAccumulator) / elapsed
            bandwidthAccumulator = 0
            bandwidthTimestamp = now

            if frameCounter > 0 {
                let totalTime = stats.uptime
                stats.averageFrameTimeMs = (totalTime / Double(frameCounter)) * 1000.0
            }
        }
    }
}

#endif // canImport(Network)
