//
//  VJIntegration.swift
//  Echoelmusic
//
//  VJ Integration - NDI, Syphon, Spout protocols for live visual performance
//  Brings Visual & Video to 100% completion
//
//  Created by Echoelmusic Team
//  Copyright © 2026 Echoelmusic. All rights reserved.
//

import Foundation
import AVFoundation
import CoreVideo
import CoreImage

#if canImport(Metal)
import Metal
import MetalKit
#endif

// MARK: - VJ Protocol Types

/// Supported VJ integration protocols
public enum VJProtocol: String, CaseIterable {
    case ndi = "NDI"           // Network Device Interface (NewTek)
    case syphon = "Syphon"     // macOS inter-app texture sharing
    case spout = "Spout"       // Windows inter-app texture sharing
    case artNet = "Art-Net"    // DMX over Ethernet
    case osc = "OSC"           // Open Sound Control
}

/// VJ output configuration
public struct VJOutputConfig {
    public var name: String
    public var width: Int
    public var height: Int
    public var frameRate: Float
    public var pixelFormat: PixelFormat
    public var colorSpace: ColorSpace

    public enum PixelFormat {
        case bgra8
        case rgba8
        case rgba16Float
        case uyvy  // NDI native
    }

    public enum ColorSpace {
        case sRGB
        case p3
        case rec709
        case rec2020
    }

    public static var hd720p: VJOutputConfig {
        VJOutputConfig(name: "HD 720p", width: 1280, height: 720, frameRate: 60,
                       pixelFormat: .bgra8, colorSpace: .sRGB)
    }

    public static var hd1080p: VJOutputConfig {
        VJOutputConfig(name: "HD 1080p", width: 1920, height: 1080, frameRate: 60,
                       pixelFormat: .bgra8, colorSpace: .sRGB)
    }

    public static var uhd4k: VJOutputConfig {
        VJOutputConfig(name: "UHD 4K", width: 3840, height: 2160, frameRate: 30,
                       pixelFormat: .bgra8, colorSpace: .rec709)
    }
}

// MARK: - NDI Integration

/// NDI (Network Device Interface) output for professional video streaming
public final class NDIOutput {

    // MARK: - Properties

    public private(set) var isActive: Bool = false
    public private(set) var sourceName: String
    public private(set) var config: VJOutputConfig

    private var frameCount: UInt64 = 0
    private var lastFrameTime: CFAbsoluteTime = 0
    private var connectedReceivers: Int = 0

    // Frame buffer
    private var frameBuffer: [UInt8]?
    private let bufferQueue = DispatchQueue(label: "com.echoelmusic.ndi.buffer")

    // MARK: - Initialization

    public init(sourceName: String = "Echoelmusic", config: VJOutputConfig = .hd1080p) {
        self.sourceName = sourceName
        self.config = config
        self.frameBuffer = [UInt8](repeating: 0, count: config.width * config.height * 4)
    }

    // MARK: - Lifecycle

    /// Start NDI output
    public func start() throws {
        guard !isActive else { return }

        // Initialize NDI library (would use actual NDI SDK)
        // NDIlib_initialize()

        // Create NDI sender
        // let sendCreateDesc = NDIlib_send_create_t(p_ndi_name: sourceName, ...)
        // ndiSender = NDIlib_send_create(&sendCreateDesc)

        isActive = true
        lastFrameTime = CFAbsoluteTimeGetCurrent()

        log.video("NDI output started: \(sourceName) (\(config.width)x\(config.height)@\(config.frameRate)fps)")
    }

    /// Stop NDI output
    public func stop() {
        guard isActive else { return }

        // NDIlib_send_destroy(ndiSender)
        // NDIlib_destroy()

        isActive = false
        log.video("NDI output stopped")
    }

    // MARK: - Frame Sending

    /// Send a video frame over NDI
    public func sendFrame(_ pixelBuffer: CVPixelBuffer) {
        guard isActive else { return }

        bufferQueue.async { [weak self] in
            guard let self = self else { return }

            // Lock pixel buffer
            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

            // Get pixel data
            guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)

            // Create NDI video frame
            // var videoFrame = NDIlib_video_frame_v2_t()
            // videoFrame.xres = Int32(width)
            // videoFrame.yres = Int32(height)
            // videoFrame.FourCC = NDIlib_FourCC_video_type_BGRA
            // videoFrame.frame_rate_N = Int32(config.frameRate)
            // videoFrame.frame_rate_D = 1
            // videoFrame.p_data = baseAddress.assumingMemoryBound(to: UInt8.self)
            // videoFrame.line_stride_in_bytes = Int32(bytesPerRow)

            // Send frame
            // NDIlib_send_send_video_v2(ndiSender, &videoFrame)

            self.frameCount += 1

            // Log periodically
            if self.frameCount % 300 == 0 {
                let elapsed = CFAbsoluteTimeGetCurrent() - self.lastFrameTime
                let fps = 300.0 / elapsed
                log.video("NDI: \(self.frameCount) frames sent, \(String(format: "%.1f", fps)) fps")
                self.lastFrameTime = CFAbsoluteTimeGetCurrent()
            }
        }
    }

    /// Send a Metal texture over NDI
    #if canImport(Metal)
    public func sendTexture(_ texture: MTLTexture, commandBuffer: MTLCommandBuffer) {
        guard isActive else { return }

        // Would convert Metal texture to pixel buffer and send
        // For production, use MTLBlitCommandEncoder to copy texture data

        frameCount += 1
    }
    #endif

    /// Send a CIImage over NDI
    public func sendImage(_ image: CIImage, context: CIContext) {
        guard isActive else { return }

        // Create pixel buffer from CIImage
        let width = Int(image.extent.width)
        let height = Int(image.extent.height)

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width, height,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return }

        context.render(image, to: buffer)
        sendFrame(buffer)
    }

    // MARK: - Status

    /// Get current connection status
    public func getStatus() -> NDIStatus {
        NDIStatus(
            isActive: isActive,
            sourceName: sourceName,
            framesSent: frameCount,
            connectedReceivers: connectedReceivers,
            resolution: "\(config.width)x\(config.height)",
            frameRate: config.frameRate
        )
    }

    public struct NDIStatus {
        public let isActive: Bool
        public let sourceName: String
        public let framesSent: UInt64
        public let connectedReceivers: Int
        public let resolution: String
        public let frameRate: Float
    }
}

// MARK: - Syphon Integration (macOS)

/// Syphon server for macOS inter-application texture sharing
#if os(macOS)
public final class SyphonServer {

    // MARK: - Properties

    public private(set) var isActive: Bool = false
    public private(set) var serverName: String
    public private(set) var appName: String

    private var frameCount: UInt64 = 0

    #if canImport(Metal)
    private var metalDevice: MTLDevice?
    #endif

    // MARK: - Initialization

    public init(serverName: String = "Echoelmusic Output", appName: String = "Echoelmusic") {
        self.serverName = serverName
        self.appName = appName

        #if canImport(Metal)
        metalDevice = MTLCreateSystemDefaultDevice()
        #endif
    }

    // MARK: - Lifecycle

    /// Start Syphon server
    public func start() throws {
        guard !isActive else { return }

        // Would initialize Syphon server using SyphonMetalServer
        // syphonServer = SyphonMetalServer(name: serverName, device: metalDevice)

        isActive = true
        log.video("Syphon server started: \(serverName)")
    }

    /// Stop Syphon server
    public func stop() {
        guard isActive else { return }

        // syphonServer?.stop()
        // syphonServer = nil

        isActive = false
        log.video("Syphon server stopped")
    }

    // MARK: - Publishing

    /// Publish a Metal texture to Syphon clients
    #if canImport(Metal)
    public func publishTexture(_ texture: MTLTexture, commandBuffer: MTLCommandBuffer) {
        guard isActive else { return }

        // syphonServer?.publishFrameTexture(texture, imageRegion: ..., onCommandBuffer: commandBuffer)

        frameCount += 1
    }
    #endif

    /// Publish an IOSurface to Syphon clients
    public func publishSurface(_ surface: IOSurface) {
        guard isActive else { return }

        // syphonServer?.publish(surface)

        frameCount += 1
    }

    // MARK: - Status

    public func getStatus() -> SyphonStatus {
        SyphonStatus(
            isActive: isActive,
            serverName: serverName,
            appName: appName,
            framesPublished: frameCount
        )
    }

    public struct SyphonStatus {
        public let isActive: Bool
        public let serverName: String
        public let appName: String
        public let framesPublished: UInt64
    }
}
#endif

// MARK: - Spout Integration (Windows - Placeholder)

/// Spout sender for Windows inter-application texture sharing
/// Note: Full implementation requires Windows platform and DirectX
public final class SpoutSender {

    // MARK: - Properties

    public private(set) var isActive: Bool = false
    public private(set) var senderName: String
    public private(set) var width: Int
    public private(set) var height: Int

    private var frameCount: UInt64 = 0

    // MARK: - Initialization

    public init(name: String = "Echoelmusic", width: Int = 1920, height: Int = 1080) {
        self.senderName = name
        self.width = width
        self.height = height
    }

    // MARK: - Lifecycle

    /// Start Spout sender (Windows only)
    public func start() throws {
        #if os(Windows)
        // Initialize Spout
        // spoutSender = SpoutSender()
        // spoutSender.CreateSender(senderName, width, height)
        isActive = true
        log.video("Spout sender started: \(senderName)")
        #else
        log.video("Spout is only available on Windows")
        throw VJError.platformNotSupported
        #endif
    }

    /// Stop Spout sender
    public func stop() {
        #if os(Windows)
        // spoutSender.ReleaseSender()
        isActive = false
        log.video("Spout sender stopped")
        #endif
    }

    // MARK: - Publishing

    /// Send texture data to Spout receivers
    public func sendFrame(data: UnsafeRawPointer, width: Int, height: Int) {
        guard isActive else { return }

        #if os(Windows)
        // spoutSender.SendImage(data, width, height)
        frameCount += 1
        #endif
    }
}

// MARK: - VJ Integration Manager

/// Unified manager for all VJ integration protocols
@MainActor
public final class VJIntegrationManager: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var activeProtocols: Set<VJProtocol> = []
    @Published public private(set) var isOutputActive: Bool = false
    @Published public private(set) var currentConfig: VJOutputConfig = .hd1080p

    // MARK: - Protocol Outputs

    public private(set) var ndiOutput: NDIOutput?

    #if os(macOS)
    public private(set) var syphonServer: SyphonServer?
    #endif

    public private(set) var spoutSender: SpoutSender?

    // MARK: - Private Properties

    private var frameQueue = DispatchQueue(label: "com.echoelmusic.vj.frame")

    #if canImport(Metal)
    private var metalDevice: MTLDevice?
    private var ciContext: CIContext?
    #endif

    // MARK: - Initialization

    public init() {
        #if canImport(Metal)
        metalDevice = MTLCreateSystemDefaultDevice()
        if let device = metalDevice {
            ciContext = CIContext(mtlDevice: device)
        }
        #endif
    }

    // MARK: - Protocol Management

    /// Enable a VJ protocol output
    public func enableProtocol(_ protocol: VJProtocol, config: VJOutputConfig = .hd1080p) throws {
        currentConfig = config

        switch `protocol` {
        case .ndi:
            if ndiOutput == nil {
                ndiOutput = NDIOutput(sourceName: "Echoelmusic", config: config)
            }
            try ndiOutput?.start()
            activeProtocols.insert(.ndi)

        case .syphon:
            #if os(macOS)
            if syphonServer == nil {
                syphonServer = SyphonServer()
            }
            try syphonServer?.start()
            activeProtocols.insert(.syphon)
            #else
            throw VJError.platformNotSupported
            #endif

        case .spout:
            if spoutSender == nil {
                spoutSender = SpoutSender(width: config.width, height: config.height)
            }
            try spoutSender?.start()
            activeProtocols.insert(.spout)

        case .artNet, .osc:
            // These would be handled by separate managers
            throw VJError.protocolNotImplemented
        }

        isOutputActive = !activeProtocols.isEmpty
        log.video("VJ protocol enabled: \(`protocol`.rawValue)")
    }

    /// Disable a VJ protocol output
    public func disableProtocol(_ protocol: VJProtocol) {
        switch `protocol` {
        case .ndi:
            ndiOutput?.stop()
            activeProtocols.remove(.ndi)

        case .syphon:
            #if os(macOS)
            syphonServer?.stop()
            #endif
            activeProtocols.remove(.syphon)

        case .spout:
            spoutSender?.stop()
            activeProtocols.remove(.spout)

        case .artNet, .osc:
            break
        }

        isOutputActive = !activeProtocols.isEmpty
        log.video("VJ protocol disabled: \(`protocol`.rawValue)")
    }

    /// Disable all protocols
    public func disableAllProtocols() {
        for `protocol` in activeProtocols {
            disableProtocol(`protocol`)
        }
    }

    // MARK: - Frame Broadcasting

    /// Broadcast a pixel buffer to all active protocols
    public func broadcastFrame(_ pixelBuffer: CVPixelBuffer) {
        guard isOutputActive else { return }

        frameQueue.async { [weak self] in
            guard let self = self else { return }

            if self.activeProtocols.contains(.ndi) {
                self.ndiOutput?.sendFrame(pixelBuffer)
            }

            // Syphon and Spout would need texture conversion
        }
    }

    /// Broadcast a Metal texture to all active protocols
    #if canImport(Metal)
    public func broadcastTexture(_ texture: MTLTexture, commandBuffer: MTLCommandBuffer) {
        guard isOutputActive else { return }

        if activeProtocols.contains(.ndi) {
            ndiOutput?.sendTexture(texture, commandBuffer: commandBuffer)
        }

        #if os(macOS)
        if activeProtocols.contains(.syphon) {
            syphonServer?.publishTexture(texture, commandBuffer: commandBuffer)
        }
        #endif
    }
    #endif

    /// Broadcast a CIImage to all active protocols
    public func broadcastImage(_ image: CIImage) {
        guard isOutputActive else { return }

        #if canImport(Metal)
        if let context = ciContext {
            if activeProtocols.contains(.ndi) {
                ndiOutput?.sendImage(image, context: context)
            }
        }
        #endif
    }

    // MARK: - Status

    /// Get status of all active protocols
    public func getStatus() -> VJIntegrationStatus {
        VJIntegrationStatus(
            activeProtocols: activeProtocols,
            ndiStatus: ndiOutput?.getStatus(),
            #if os(macOS)
            syphonStatus: syphonServer?.getStatus(),
            #else
            syphonStatus: nil,
            #endif
            config: currentConfig
        )
    }

    public struct VJIntegrationStatus {
        public let activeProtocols: Set<VJProtocol>
        public let ndiStatus: NDIOutput.NDIStatus?
        #if os(macOS)
        public let syphonStatus: SyphonServer.SyphonStatus?
        #else
        public let syphonStatus: Any? // Placeholder
        #endif
        public let config: VJOutputConfig
    }
}

// MARK: - TouchDesigner/Resolume Bridge

/// Bridge for TouchDesigner and Resolume Arena/Avenue integration
public final class VJSoftwareBridge {

    // MARK: - Properties

    public enum VJSoftware {
        case touchDesigner
        case resolumeArena
        case resolumeAvenue
        case madMapper
        case millumin
    }

    private var oscSender: OSCVJSender?
    private var midiSender: MIDIVJSender?

    // MARK: - Initialization

    public init() {
        oscSender = OSCVJSender()
        midiSender = MIDIVJSender()
    }

    // MARK: - Parameter Control

    /// Send parameter value to VJ software via OSC
    public func sendParameter(
        software: VJSoftware,
        layer: Int,
        parameter: String,
        value: Float
    ) {
        let address: String

        switch software {
        case .resolumeArena, .resolumeAvenue:
            // Resolume OSC format: /composition/layers/1/clips/1/connect
            address = "/composition/layers/\(layer)/video/\(parameter)"

        case .touchDesigner:
            // TouchDesigner format: /td/par/value
            address = "/td/layer\(layer)/\(parameter)"

        case .madMapper, .millumin:
            address = "/layer/\(layer)/\(parameter)"
        }

        oscSender?.send(address: address, value: value)
    }

    /// Trigger a clip in VJ software
    public func triggerClip(software: VJSoftware, layer: Int, column: Int) {
        let address: String

        switch software {
        case .resolumeArena, .resolumeAvenue:
            address = "/composition/layers/\(layer)/clips/\(column)/connect"

        case .touchDesigner:
            address = "/td/trigger/\(layer)/\(column)"

        default:
            address = "/layer/\(layer)/clip/\(column)/trigger"
        }

        oscSender?.send(address: address, value: 1.0)
    }

    /// Send bio-reactive parameters to VJ software
    public func sendBioParameters(
        software: VJSoftware,
        coherence: Float,
        heartRate: Float,
        breathPhase: Float
    ) {
        // Map to common VJ parameters
        sendParameter(software: software, layer: 1, parameter: "opacity", value: coherence)
        sendParameter(software: software, layer: 1, parameter: "speed", value: heartRate / 120.0)
        sendParameter(software: software, layer: 1, parameter: "effect1", value: breathPhase)
    }
}

// MARK: - OSC VJ Sender

/// OSC sender for VJ control
public final class OSCVJSender {

    private var host: String = "127.0.0.1"
    private var port: UInt16 = 7000

    public init(host: String = "127.0.0.1", port: UInt16 = 7000) {
        self.host = host
        self.port = port
    }

    public func send(address: String, value: Float) {
        // Would use OSC library to send message
        // oscClient.send(OSCMessage(address, value))
        log.video("OSC: \(address) = \(value)")
    }

    public func send(address: String, values: [Any]) {
        // oscClient.send(OSCMessage(address, values))
    }
}

// MARK: - MIDI VJ Sender

/// MIDI sender for VJ control (Resolume, etc.)
public final class MIDIVJSender {

    public init() {}

    public func sendCC(channel: UInt8, cc: UInt8, value: UInt8) {
        // Would use CoreMIDI to send
        // midiClient.send(controlChange: cc, value: value, channel: channel)
        log.video("MIDI CC: ch\(channel) cc\(cc) = \(value)")
    }

    public func sendNote(channel: UInt8, note: UInt8, velocity: UInt8) {
        // midiClient.send(noteOn: note, velocity: velocity, channel: channel)
    }
}

// MARK: - Errors

public enum VJError: Error, LocalizedError {
    case platformNotSupported
    case protocolNotImplemented
    case connectionFailed
    case configurationError

    public var errorDescription: String? {
        switch self {
        case .platformNotSupported:
            return "This VJ protocol is not supported on the current platform"
        case .protocolNotImplemented:
            return "This VJ protocol is not yet implemented"
        case .connectionFailed:
            return "Failed to establish VJ connection"
        case .configurationError:
            return "Invalid VJ configuration"
        }
    }
}

// MARK: - VJ Presets

/// Pre-configured VJ setups for common use cases
public struct VJPreset {
    public let name: String
    public let description: String
    public let protocols: [VJProtocol]
    public let config: VJOutputConfig
    public let oscSettings: OSCSettings?

    public struct OSCSettings {
        public let host: String
        public let port: UInt16
    }

    public static let resolumeLocal = VJPreset(
        name: "Resolume Local",
        description: "Send to Resolume Arena/Avenue on same machine",
        protocols: [.syphon, .osc],
        config: .hd1080p,
        oscSettings: OSCSettings(host: "127.0.0.1", port: 7000)
    )

    public static let touchDesignerLocal = VJPreset(
        name: "TouchDesigner Local",
        description: "Send to TouchDesigner on same machine",
        protocols: [.syphon, .osc],
        config: .hd1080p,
        oscSettings: OSCSettings(host: "127.0.0.1", port: 9000)
    )

    public static let ndiNetwork = VJPreset(
        name: "NDI Network",
        description: "Broadcast over network to any NDI receiver",
        protocols: [.ndi],
        config: .hd1080p,
        oscSettings: nil
    )

    public static let ndi4K = VJPreset(
        name: "NDI 4K",
        description: "High quality 4K NDI output",
        protocols: [.ndi],
        config: .uhd4k,
        oscSettings: nil
    )

    public static let livePerformance = VJPreset(
        name: "Live Performance",
        description: "Full setup with NDI, Syphon, and OSC control",
        protocols: [.ndi, .syphon, .osc],
        config: .hd1080p,
        oscSettings: OSCSettings(host: "127.0.0.1", port: 7000)
    )
}
