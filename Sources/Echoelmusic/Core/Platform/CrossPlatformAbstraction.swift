//
//  CrossPlatformAbstraction.swift
//  Echoelmusic
//
//  Created: 2025-11-28
//  Lead Developer Architecture for Ultra-Low Latency Cross-Platform Support
//
//  Targets: iOS, macOS, Windows, Android, Linux, Tesla, CarPlay, visionOS
//

import Foundation

// MARK: - Audio Driver Abstraction

/// Protocol for cross-platform audio driver implementations
/// Enables ultra-low latency audio on any platform
public protocol AudioDriverProtocol: AnyObject {
    /// Current sample rate
    var sampleRate: Double { get }

    /// Buffer size in frames
    var bufferSize: Int { get }

    /// Round-trip latency in seconds
    var latency: TimeInterval { get }

    /// Whether the driver is currently running
    var isRunning: Bool { get }

    /// Start audio processing
    func start() async throws

    /// Stop audio processing
    func stop() async throws

    /// Set buffer size (lower = lower latency, higher CPU)
    func setBufferSize(_ size: Int) throws

    /// Set sample rate
    func setSampleRate(_ rate: Double) throws

    /// Process audio callback - called on real-time thread
    var processCallback: ((_ inputBuffer: UnsafePointer<Float>?,
                           _ outputBuffer: UnsafeMutablePointer<Float>,
                           _ frameCount: Int,
                           _ timestamp: UInt64) -> Void)? { get set }
}

// MARK: - Video Codec Abstraction

/// Protocol for cross-platform video codec implementations
public protocol VideoCodecProtocol {
    /// Codec identifier
    var codecId: String { get }

    /// Whether hardware acceleration is available
    var isHardwareAccelerated: Bool { get }

    /// Supported pixel formats
    var supportedPixelFormats: [PixelFormat] { get }

    /// Encode frame to compressed data
    func encode(pixelBuffer: UnsafeRawPointer, width: Int, height: Int, format: PixelFormat) throws -> Data

    /// Decode compressed data to pixel buffer
    func decode(data: Data) throws -> DecodedFrame

    /// Flush encoder/decoder buffers
    func flush() throws
}

/// Cross-platform pixel format enumeration
public enum PixelFormat: String, CaseIterable {
    case rgba8 = "RGBA8"
    case bgra8 = "BGRA8"
    case yuv420p = "YUV420P"
    case yuv422p = "YUV422P"
    case yuv444p = "YUV444P"
    case nv12 = "NV12"
    case p010 = "P010"  // 10-bit HDR
    case rgba16f = "RGBA16F"  // Float HDR
}

/// Decoded video frame
public struct DecodedFrame {
    public let data: Data
    public let width: Int
    public let height: Int
    public let format: PixelFormat
    public let timestamp: UInt64
    public let isKeyframe: Bool
}

// MARK: - Graphics Abstraction

/// Protocol for cross-platform GPU graphics
/// Abstracts Metal, Vulkan, DirectX, OpenGL
public protocol GraphicsDeviceProtocol: AnyObject {
    /// Device name
    var deviceName: String { get }

    /// Maximum texture size
    var maxTextureSize: Int { get }

    /// Available VRAM in bytes
    var availableMemory: UInt64 { get }

    /// Create a GPU buffer
    func createBuffer(size: Int, usage: BufferUsage) -> GraphicsBuffer?

    /// Create a texture
    func createTexture(width: Int, height: Int, format: PixelFormat, usage: TextureUsage) -> GraphicsTexture?

    /// Create a render pipeline
    func createRenderPipeline(vertexShader: String, fragmentShader: String) throws -> RenderPipeline

    /// Create a compute pipeline
    func createComputePipeline(computeShader: String) throws -> ComputePipeline

    /// Submit command buffer for execution
    func submitCommandBuffer(_ buffer: CommandBuffer) throws

    /// Wait for GPU to complete all work
    func waitForIdle()
}

/// Buffer usage flags
public struct BufferUsage: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let vertex = BufferUsage(rawValue: 1 << 0)
    public static let index = BufferUsage(rawValue: 1 << 1)
    public static let uniform = BufferUsage(rawValue: 1 << 2)
    public static let storage = BufferUsage(rawValue: 1 << 3)
    public static let transferSrc = BufferUsage(rawValue: 1 << 4)
    public static let transferDst = BufferUsage(rawValue: 1 << 5)
}

/// Texture usage flags
public struct TextureUsage: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let shaderRead = TextureUsage(rawValue: 1 << 0)
    public static let shaderWrite = TextureUsage(rawValue: 1 << 1)
    public static let renderTarget = TextureUsage(rawValue: 1 << 2)
    public static let transferSrc = TextureUsage(rawValue: 1 << 3)
    public static let transferDst = TextureUsage(rawValue: 1 << 4)
}

/// Abstract GPU buffer
public protocol GraphicsBuffer {
    var size: Int { get }
    func update(data: UnsafeRawPointer, size: Int, offset: Int)
}

/// Abstract GPU texture
public protocol GraphicsTexture {
    var width: Int { get }
    var height: Int { get }
    var format: PixelFormat { get }
    func update(data: UnsafeRawPointer, bytesPerRow: Int)
}

/// Abstract render pipeline
public protocol RenderPipeline {
    var vertexShaderName: String { get }
    var fragmentShaderName: String { get }
}

/// Abstract compute pipeline
public protocol ComputePipeline {
    var computeShaderName: String { get }
}

/// Abstract command buffer
public protocol CommandBuffer {
    func beginRenderPass(target: GraphicsTexture, clearColor: (Float, Float, Float, Float)?)
    func endRenderPass()
    func setRenderPipeline(_ pipeline: RenderPipeline)
    func setComputePipeline(_ pipeline: ComputePipeline)
    func setVertexBuffer(_ buffer: GraphicsBuffer, offset: Int, index: Int)
    func setFragmentTexture(_ texture: GraphicsTexture, index: Int)
    func drawPrimitives(vertexStart: Int, vertexCount: Int)
    func dispatchCompute(threadgroupsPerGrid: (Int, Int, Int), threadsPerThreadgroup: (Int, Int, Int))
}

// MARK: - MIDI Abstraction

/// Protocol for cross-platform MIDI
public protocol MIDIDriverProtocol: AnyObject {
    /// Available MIDI input ports
    var inputPorts: [MIDIPort] { get }

    /// Available MIDI output ports
    var outputPorts: [MIDIPort] { get }

    /// Refresh port list
    func refreshPorts()

    /// Open an input port
    func openInput(port: MIDIPort) throws

    /// Open an output port
    func openOutput(port: MIDIPort) throws

    /// Close a port
    func close(port: MIDIPort)

    /// Send MIDI message
    func send(message: MIDIMessage, to port: MIDIPort) throws

    /// MIDI input callback
    var onMIDIReceived: ((_ message: MIDIMessage, _ port: MIDIPort, _ timestamp: UInt64) -> Void)? { get set }
}

/// MIDI port representation
public struct MIDIPort: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let manufacturer: String
    public let isInput: Bool
    public let isVirtual: Bool
}

/// Cross-platform MIDI message
public struct MIDIMessage {
    public let status: UInt8
    public let data1: UInt8
    public let data2: UInt8
    public let channel: UInt8

    public init(status: UInt8, data1: UInt8, data2: UInt8 = 0) {
        self.status = status
        self.data1 = data1
        self.data2 = data2
        self.channel = status & 0x0F
    }

    /// Note On message
    public static func noteOn(channel: UInt8, note: UInt8, velocity: UInt8) -> MIDIMessage {
        MIDIMessage(status: 0x90 | (channel & 0x0F), data1: note, data2: velocity)
    }

    /// Note Off message
    public static func noteOff(channel: UInt8, note: UInt8, velocity: UInt8 = 0) -> MIDIMessage {
        MIDIMessage(status: 0x80 | (channel & 0x0F), data1: note, data2: velocity)
    }

    /// Control Change message
    public static func controlChange(channel: UInt8, controller: UInt8, value: UInt8) -> MIDIMessage {
        MIDIMessage(status: 0xB0 | (channel & 0x0F), data1: controller, data2: value)
    }

    /// Program Change message
    public static func programChange(channel: UInt8, program: UInt8) -> MIDIMessage {
        MIDIMessage(status: 0xC0 | (channel & 0x0F), data1: program)
    }

    /// Pitch Bend message
    public static func pitchBend(channel: UInt8, value: UInt16) -> MIDIMessage {
        let lsb = UInt8(value & 0x7F)
        let msb = UInt8((value >> 7) & 0x7F)
        return MIDIMessage(status: 0xE0 | (channel & 0x0F), data1: lsb, data2: msb)
    }
}

// MARK: - Lighting Protocol Abstraction

/// Protocol for professional lighting control
public protocol LightingProtocolDriver: AnyObject {
    /// Protocol name
    var protocolName: String { get }

    /// Whether connected/ready
    var isConnected: Bool { get }

    /// Connect to lighting system
    func connect() async throws

    /// Disconnect
    func disconnect()

    /// Send DMX universe data (512 channels)
    func sendDMXUniverse(_ universe: Int, channels: [UInt8]) async throws

    /// Set individual channel
    func setChannel(_ universe: Int, channel: Int, value: UInt8) async throws

    /// Get current channel values
    func getChannelValues(_ universe: Int) -> [UInt8]
}

// MARK: - Platform Detection

/// Detect current platform and capabilities
public struct PlatformInfo {
    public static var current: Platform {
        #if os(iOS)
        return .iOS
        #elseif os(macOS)
        return .macOS
        #elseif os(tvOS)
        return .tvOS
        #elseif os(watchOS)
        return .watchOS
        #elseif os(visionOS)
        return .visionOS
        #elseif os(Windows)
        return .windows
        #elseif os(Android)
        return .android
        #elseif os(Linux)
        return .linux
        #else
        return .unknown
        #endif
    }

    public enum Platform: String {
        case iOS, macOS, tvOS, watchOS, visionOS
        case windows, android, linux
        case tesla, carPlay
        case unknown

        public var supportsHardwareVideo: Bool {
            switch self {
            case .iOS, .macOS, .tvOS, .visionOS: return true  // VideoToolbox
            case .windows: return true  // Media Foundation
            case .android: return true  // MediaCodec
            case .linux: return false  // Software only typically
            default: return false
            }
        }

        public var primaryGraphicsAPI: String {
            switch self {
            case .iOS, .macOS, .tvOS, .watchOS, .visionOS: return "Metal"
            case .windows: return "DirectX12"
            case .android, .linux: return "Vulkan"
            case .tesla: return "OpenGL ES"
            default: return "OpenGL"
            }
        }

        public var primaryAudioAPI: String {
            switch self {
            case .iOS, .macOS, .tvOS, .watchOS, .visionOS: return "AVAudioEngine"
            case .windows: return "WASAPI"
            case .android: return "AAudio"
            case .linux: return "PulseAudio"
            case .tesla: return "ALSA"
            default: return "Unknown"
            }
        }
    }
}

// MARK: - Driver Factory

/// Factory for creating platform-specific drivers
public final class DriverFactory {
    public static let shared = DriverFactory()
    private init() {}

    /// Create audio driver for current platform
    public func createAudioDriver() -> AudioDriverProtocol {
        switch PlatformInfo.current {
        case .iOS, .macOS, .tvOS, .watchOS, .visionOS:
            return AppleAudioDriver()
        // Future implementations:
        // case .windows: return WASAPIAudioDriver()
        // case .android: return AAudioDriver()
        // case .linux: return PulseAudioDriver()
        default:
            return AppleAudioDriver()  // Fallback
        }
    }

    /// Create MIDI driver for current platform
    public func createMIDIDriver() -> MIDIDriverProtocol {
        switch PlatformInfo.current {
        case .iOS, .macOS, .tvOS, .visionOS:
            return AppleMIDIDriver()
        // Future implementations:
        // case .windows: return WindowsMIDIDriver()
        // case .android: return AndroidMIDIDriver()
        // case .linux: return ALSAMIDIDriver()
        default:
            return AppleMIDIDriver()  // Fallback
        }
    }

    /// Create graphics device for current platform
    public func createGraphicsDevice() -> GraphicsDeviceProtocol? {
        switch PlatformInfo.current {
        case .iOS, .macOS, .tvOS, .visionOS:
            return MetalGraphicsDevice()
        // Future implementations:
        // case .windows: return DirectXGraphicsDevice()
        // case .android, .linux: return VulkanGraphicsDevice()
        default:
            return MetalGraphicsDevice()  // Fallback
        }
    }
}

// MARK: - Apple Platform Implementations

#if canImport(AVFoundation)
import AVFoundation

/// Apple AVAudioEngine-based audio driver
public final class AppleAudioDriver: AudioDriverProtocol {
    private let engine = AVAudioEngine()
    private var _sampleRate: Double = 48000
    private var _bufferSize: Int = 256

    public var sampleRate: Double { _sampleRate }
    public var bufferSize: Int { _bufferSize }

    public var latency: TimeInterval {
        Double(_bufferSize) / _sampleRate
    }

    public var isRunning: Bool { engine.isRunning }

    public var processCallback: ((UnsafePointer<Float>?, UnsafeMutablePointer<Float>, Int, UInt64) -> Void)?

    public func start() async throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setPreferredSampleRate(_sampleRate)
        try audioSession.setPreferredIOBufferDuration(Double(_bufferSize) / _sampleRate)
        try audioSession.setActive(true)

        _sampleRate = audioSession.sampleRate

        // Install tap for processing
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(_bufferSize), format: format) { [weak self] buffer, time in
            guard let callback = self?.processCallback,
                  let channelData = buffer.floatChannelData else { return }

            let frameCount = Int(buffer.frameLength)
            let timestamp = time.hostTime

            // Call processing callback
            callback(channelData[0], channelData[0], frameCount, timestamp)
        }

        engine.prepare()
        try engine.start()
    }

    public func stop() async throws {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    public func setBufferSize(_ size: Int) throws {
        let validSizes = [64, 128, 256, 512, 1024, 2048]
        guard validSizes.contains(size) else {
            throw AudioDriverError.invalidBufferSize
        }
        _bufferSize = size

        if engine.isRunning {
            try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(Double(size) / _sampleRate)
        }
    }

    public func setSampleRate(_ rate: Double) throws {
        let validRates = [44100.0, 48000.0, 88200.0, 96000.0]
        guard validRates.contains(rate) else {
            throw AudioDriverError.invalidSampleRate
        }
        _sampleRate = rate

        if engine.isRunning {
            try AVAudioSession.sharedInstance().setPreferredSampleRate(rate)
        }
    }
}

public enum AudioDriverError: Error {
    case invalidBufferSize
    case invalidSampleRate
    case driverNotAvailable
}
#endif

#if canImport(CoreMIDI)
import CoreMIDI

/// Apple CoreMIDI-based MIDI driver
public final class AppleMIDIDriver: MIDIDriverProtocol {
    private var client: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0
    private var outputPort: MIDIPortRef = 0

    public private(set) var inputPorts: [MIDIPort] = []
    public private(set) var outputPorts: [MIDIPort] = []

    public var onMIDIReceived: ((MIDIMessage, MIDIPort, UInt64) -> Void)?

    public init() {
        setupMIDI()
    }

    private func setupMIDI() {
        MIDIClientCreate("EchoelMIDI" as CFString, nil, nil, &client)

        MIDIInputPortCreate(client, "Input" as CFString, { packetList, srcConnRefCon, connRefCon in
            // MIDI receive callback - would be implemented here
        }, nil, &inputPort)

        MIDIOutputPortCreate(client, "Output" as CFString, &outputPort)

        refreshPorts()
    }

    public func refreshPorts() {
        inputPorts = []
        outputPorts = []

        // Get input sources
        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            if let port = createMIDIPort(from: source, isInput: true) {
                inputPorts.append(port)
            }
        }

        // Get output destinations
        let destCount = MIDIGetNumberOfDestinations()
        for i in 0..<destCount {
            let dest = MIDIGetDestination(i)
            if let port = createMIDIPort(from: dest, isInput: false) {
                outputPorts.append(port)
            }
        }
    }

    private func createMIDIPort(from endpoint: MIDIEndpointRef, isInput: Bool) -> MIDIPort? {
        var name: Unmanaged<CFString>?
        var manufacturer: Unmanaged<CFString>?

        MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name)
        MIDIObjectGetStringProperty(endpoint, kMIDIPropertyManufacturer, &manufacturer)

        guard let portName = name?.takeRetainedValue() as String? else { return nil }

        return MIDIPort(
            id: "\(endpoint)",
            name: portName,
            manufacturer: (manufacturer?.takeRetainedValue() as String?) ?? "Unknown",
            isInput: isInput,
            isVirtual: false
        )
    }

    public func openInput(port: MIDIPort) throws {
        guard let endpoint = UInt32(port.id) else { return }
        MIDIPortConnectSource(inputPort, endpoint, nil)
    }

    public func openOutput(port: MIDIPort) throws {
        // Output ports don't need explicit opening in CoreMIDI
    }

    public func close(port: MIDIPort) {
        if port.isInput, let endpoint = UInt32(port.id) {
            MIDIPortDisconnectSource(inputPort, endpoint)
        }
    }

    public func send(message: MIDIMessage, to port: MIDIPort) throws {
        guard let endpoint = UInt32(port.id) else { return }

        var packet = MIDIPacket()
        packet.timeStamp = 0
        packet.length = 3
        packet.data.0 = message.status
        packet.data.1 = message.data1
        packet.data.2 = message.data2

        var packetList = MIDIPacketList(numPackets: 1, packet: packet)
        MIDISend(outputPort, endpoint, &packetList)
    }
}
#endif

#if canImport(Metal)
import Metal

/// Metal-based graphics device
public final class MetalGraphicsDevice: GraphicsDeviceProtocol {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue

    public var deviceName: String { device.name }
    public var maxTextureSize: Int { 16384 }  // Metal supports up to 16K
    public var availableMemory: UInt64 { device.recommendedMaxWorkingSetSize }

    public init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            return nil
        }
        self.device = device
        self.commandQueue = queue
    }

    public func createBuffer(size: Int, usage: BufferUsage) -> GraphicsBuffer? {
        guard let buffer = device.makeBuffer(length: size, options: .storageModeShared) else {
            return nil
        }
        return MetalBuffer(buffer: buffer)
    }

    public func createTexture(width: Int, height: Int, format: PixelFormat, usage: TextureUsage) -> GraphicsTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: format.metalFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = usage.metalUsage

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }
        return MetalTexture(texture: texture, format: format)
    }

    public func createRenderPipeline(vertexShader: String, fragmentShader: String) throws -> RenderPipeline {
        guard let library = device.makeDefaultLibrary(),
              let vertexFunction = library.makeFunction(name: vertexShader),
              let fragmentFunction = library.makeFunction(name: fragmentShader) else {
            throw GraphicsError.shaderCompilationFailed
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        let state = try device.makeRenderPipelineState(descriptor: descriptor)
        return MetalRenderPipeline(state: state, vertexName: vertexShader, fragmentName: fragmentShader)
    }

    public func createComputePipeline(computeShader: String) throws -> ComputePipeline {
        guard let library = device.makeDefaultLibrary(),
              let function = library.makeFunction(name: computeShader) else {
            throw GraphicsError.shaderCompilationFailed
        }

        let state = try device.makeComputePipelineState(function: function)
        return MetalComputePipeline(state: state, computeName: computeShader)
    }

    public func submitCommandBuffer(_ buffer: CommandBuffer) throws {
        guard let metalBuffer = buffer as? MetalCommandBuffer else {
            throw GraphicsError.invalidCommandBuffer
        }
        metalBuffer.commandBuffer.commit()
    }

    public func waitForIdle() {
        let buffer = commandQueue.makeCommandBuffer()
        buffer?.commit()
        buffer?.waitUntilCompleted()
    }
}

public enum GraphicsError: Error {
    case shaderCompilationFailed
    case invalidCommandBuffer
    case textureCreationFailed
}

// Metal implementations of abstract types
final class MetalBuffer: GraphicsBuffer {
    let buffer: MTLBuffer
    var size: Int { buffer.length }

    init(buffer: MTLBuffer) { self.buffer = buffer }

    func update(data: UnsafeRawPointer, size: Int, offset: Int) {
        memcpy(buffer.contents().advanced(by: offset), data, size)
    }
}

final class MetalTexture: GraphicsTexture {
    let texture: MTLTexture
    let format: PixelFormat

    var width: Int { texture.width }
    var height: Int { texture.height }

    init(texture: MTLTexture, format: PixelFormat) {
        self.texture = texture
        self.format = format
    }

    func update(data: UnsafeRawPointer, bytesPerRow: Int) {
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: data,
            bytesPerRow: bytesPerRow
        )
    }
}

final class MetalRenderPipeline: RenderPipeline {
    let state: MTLRenderPipelineState
    let vertexShaderName: String
    let fragmentShaderName: String

    init(state: MTLRenderPipelineState, vertexName: String, fragmentName: String) {
        self.state = state
        self.vertexShaderName = vertexName
        self.fragmentShaderName = fragmentName
    }
}

final class MetalComputePipeline: ComputePipeline {
    let state: MTLComputePipelineState
    let computeShaderName: String

    init(state: MTLComputePipelineState, computeName: String) {
        self.state = state
        self.computeShaderName = computeName
    }
}

final class MetalCommandBuffer: CommandBuffer {
    let commandBuffer: MTLCommandBuffer
    var renderEncoder: MTLRenderCommandEncoder?
    var computeEncoder: MTLComputeCommandEncoder?

    init(commandBuffer: MTLCommandBuffer) {
        self.commandBuffer = commandBuffer
    }

    func beginRenderPass(target: GraphicsTexture, clearColor: (Float, Float, Float, Float)?) {
        guard let metalTexture = target as? MetalTexture else { return }

        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = metalTexture.texture
        descriptor.colorAttachments[0].loadAction = clearColor != nil ? .clear : .load
        descriptor.colorAttachments[0].storeAction = .store

        if let color = clearColor {
            descriptor.colorAttachments[0].clearColor = MTLClearColor(
                red: Double(color.0), green: Double(color.1),
                blue: Double(color.2), alpha: Double(color.3)
            )
        }

        renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
    }

    func endRenderPass() {
        renderEncoder?.endEncoding()
        renderEncoder = nil
    }

    func setRenderPipeline(_ pipeline: RenderPipeline) {
        guard let metalPipeline = pipeline as? MetalRenderPipeline else { return }
        renderEncoder?.setRenderPipelineState(metalPipeline.state)
    }

    func setComputePipeline(_ pipeline: ComputePipeline) {
        guard let metalPipeline = pipeline as? MetalComputePipeline else { return }
        computeEncoder = commandBuffer.makeComputeCommandEncoder()
        computeEncoder?.setComputePipelineState(metalPipeline.state)
    }

    func setVertexBuffer(_ buffer: GraphicsBuffer, offset: Int, index: Int) {
        guard let metalBuffer = buffer as? MetalBuffer else { return }
        renderEncoder?.setVertexBuffer(metalBuffer.buffer, offset: offset, index: index)
    }

    func setFragmentTexture(_ texture: GraphicsTexture, index: Int) {
        guard let metalTexture = texture as? MetalTexture else { return }
        renderEncoder?.setFragmentTexture(metalTexture.texture, index: index)
    }

    func drawPrimitives(vertexStart: Int, vertexCount: Int) {
        renderEncoder?.drawPrimitives(type: .triangle, vertexStart: vertexStart, vertexCount: vertexCount)
    }

    func dispatchCompute(threadgroupsPerGrid: (Int, Int, Int), threadsPerThreadgroup: (Int, Int, Int)) {
        computeEncoder?.dispatchThreadgroups(
            MTLSize(width: threadgroupsPerGrid.0, height: threadgroupsPerGrid.1, depth: threadgroupsPerGrid.2),
            threadsPerThreadgroup: MTLSize(width: threadsPerThreadgroup.0, height: threadsPerThreadgroup.1, depth: threadsPerThreadgroup.2)
        )
        computeEncoder?.endEncoding()
        computeEncoder = nil
    }
}

extension PixelFormat {
    var metalFormat: MTLPixelFormat {
        switch self {
        case .rgba8: return .rgba8Unorm
        case .bgra8: return .bgra8Unorm
        case .rgba16f: return .rgba16Float
        case .yuv420p, .yuv422p, .yuv444p, .nv12, .p010:
            return .bgra8Unorm  // Needs conversion
        }
    }
}

extension TextureUsage {
    var metalUsage: MTLTextureUsage {
        var usage: MTLTextureUsage = []
        if contains(.shaderRead) { usage.insert(.shaderRead) }
        if contains(.shaderWrite) { usage.insert(.shaderWrite) }
        if contains(.renderTarget) { usage.insert(.renderTarget) }
        return usage
    }
}
#endif
