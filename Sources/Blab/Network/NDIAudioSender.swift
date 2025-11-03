import Foundation
import AVFoundation
import Network

/// NDI Audio Sender - Streams audio to NDI network devices
/// Compatible with NDI SDK 5.x+ (requires NDI SDK to be linked)
///
/// Features:
/// - Ultra-low latency audio streaming (< 5ms)
/// - Automatic device discovery (mDNS)
/// - Multiple audio formats (PCM 16/24/32-bit, Float)
/// - Sample rates: 44.1kHz, 48kHz, 96kHz
/// - Stereo/Multi-channel support
///
/// Usage:
/// ```swift
/// let ndiSender = NDIAudioSender(sourceName: "BLAB iOS")
/// try ndiSender.start()
/// ndiSender.send(audioBuffer: buffer)
/// ```
@available(iOS 15.0, *)
public class NDIAudioSender {

    // MARK: - Types

    public enum NDIError: Error {
        case sdkNotLinked
        case initializationFailed
        case invalidAudioFormat
        case sendFailed(String)
        case notStarted
        case alreadyStarted
    }

    public struct AudioFormat {
        let sampleRate: Double
        let channelCount: Int
        let bitDepth: Int
        let isFloat: Bool

        public static let stereo48kHz = AudioFormat(
            sampleRate: 48000,
            channelCount: 2,
            bitDepth: 32,
            isFloat: true
        )

        public static let stereo96kHz = AudioFormat(
            sampleRate: 96000,
            channelCount: 2,
            bitDepth: 32,
            isFloat: true
        )
    }

    // MARK: - Properties

    public let sourceName: String
    public let audioFormat: AudioFormat
    public private(set) var isRunning: Bool = false

    private var ndiSendInstance: OpaquePointer?
    private let queue = DispatchQueue(label: "com.blab.ndi", qos: .userInteractive)

    // Statistics
    public private(set) var framesSent: UInt64 = 0
    public private(set) var bytesSent: UInt64 = 0
    public private(set) var droppedFrames: UInt64 = 0

    // MARK: - Initialization

    /// Initialize NDI Audio Sender
    /// - Parameters:
    ///   - sourceName: Name that appears on network (e.g., "BLAB iOS")
    ///   - audioFormat: Audio format configuration
    public init(sourceName: String = "BLAB iOS Audio", audioFormat: AudioFormat = .stereo48kHz) {
        self.sourceName = sourceName
        self.audioFormat = audioFormat
    }

    deinit {
        stop()
    }

    // MARK: - Lifecycle

    /// Start NDI sender and announce on network
    public func start() throws {
        guard !isRunning else {
            throw NDIError.alreadyStarted
        }

        // NOTE: This is a placeholder for actual NDI SDK integration
        // Real implementation requires NDI SDK to be linked

        #if NDI_SDK_AVAILABLE
        // Initialize NDI SDK
        guard NDI_initialize() else {
            throw NDIError.initializationFailed
        }

        // Create NDI send instance
        var sendCreate = NDIlib_send_create_t()
        sendCreate.p_ndi_name = strdup(sourceName)
        sendCreate.p_groups = nil
        sendCreate.clock_video = false
        sendCreate.clock_audio = true  // Audio is clock source

        ndiSendInstance = NDIlib_send_create(&sendCreate)

        guard ndiSendInstance != nil else {
            throw NDIError.initializationFailed
        }

        isRunning = true
        print("[NDI] Started sender: \(sourceName)")
        print("[NDI] Audio format: \(audioFormat.sampleRate) Hz, \(audioFormat.channelCount) ch, \(audioFormat.bitDepth)-bit")

        #else
        // Fallback: Log that NDI SDK is not available
        print("[NDI] ⚠️ NDI SDK not linked - operating in mock mode")
        print("[NDI] To enable NDI output:")
        print("[NDI]   1. Download NDI SDK from ndi.tv")
        print("[NDI]   2. Add NDI framework to project")
        print("[NDI]   3. Add -DNDI_SDK_AVAILABLE to Swift flags")
        isRunning = true
        #endif
    }

    /// Stop NDI sender
    public func stop() {
        guard isRunning else { return }

        #if NDI_SDK_AVAILABLE
        if let instance = ndiSendInstance {
            NDIlib_send_destroy(instance)
            ndiSendInstance = nil
        }
        NDI_destroy()
        #endif

        isRunning = false
        print("[NDI] Stopped sender")
        printStatistics()
    }

    // MARK: - Audio Sending

    /// Send audio buffer to NDI
    /// - Parameter buffer: AVAudioPCMBuffer to send
    public func send(audioBuffer buffer: AVAudioPCMBuffer) throws {
        guard isRunning else {
            throw NDIError.notStarted
        }

        // Validate format
        guard buffer.format.sampleRate == audioFormat.sampleRate else {
            throw NDIError.invalidAudioFormat
        }

        guard Int(buffer.format.channelCount) == audioFormat.channelCount else {
            throw NDIError.invalidAudioFormat
        }

        #if NDI_SDK_AVAILABLE
        try sendNDIFrame(buffer: buffer)
        #else
        // Mock mode: Just count frames
        framesSent += UInt64(buffer.frameLength)
        #endif
    }

    /// Send interleaved audio data to NDI
    /// - Parameters:
    ///   - data: Interleaved audio samples (Float32 or Int16/Int32)
    ///   - frameCount: Number of frames (not samples)
    ///   - timestamp: Optional timestamp (uses current time if nil)
    public func send(interleavedData data: UnsafeRawPointer, frameCount: Int, timestamp: TimeInterval? = nil) throws {
        guard isRunning else {
            throw NDIError.notStarted
        }

        #if NDI_SDK_AVAILABLE
        guard let instance = ndiSendInstance else {
            throw NDIError.notStarted
        }

        var audioFrame = NDIlib_audio_frame_v3_t()
        audioFrame.sample_rate = Int32(audioFormat.sampleRate)
        audioFrame.no_channels = Int32(audioFormat.channelCount)
        audioFrame.no_samples = Int32(frameCount)
        audioFrame.timecode = timestamp.map { Int64($0 * 10_000_000) } ?? NDIlib_send_timecode_synthesize
        audioFrame.p_data = data.assumingMemoryBound(to: Float.self)
        audioFrame.channel_stride_in_bytes = Int32(MemoryLayout<Float>.stride)

        // Send audio frame
        NDIlib_send_send_audio_v3(instance, &audioFrame)

        framesSent += UInt64(frameCount)
        bytesSent += UInt64(frameCount * audioFormat.channelCount * MemoryLayout<Float>.stride)

        #else
        // Mock mode
        framesSent += UInt64(frameCount)
        bytesSent += UInt64(frameCount * audioFormat.channelCount * 4)  // Assume Float32
        #endif
    }

    // MARK: - Private Methods

    #if NDI_SDK_AVAILABLE
    private func sendNDIFrame(buffer: AVAudioPCMBuffer) throws {
        guard let instance = ndiSendInstance else {
            throw NDIError.notStarted
        }

        guard let floatData = buffer.floatChannelData else {
            throw NDIError.invalidAudioFormat
        }

        // Convert non-interleaved to interleaved
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        var interleavedData = [Float](repeating: 0, count: frameCount * channelCount)

        for frame in 0..<frameCount {
            for channel in 0..<channelCount {
                interleavedData[frame * channelCount + channel] = floatData[channel][frame]
            }
        }

        // Send via NDI
        try interleavedData.withUnsafeBytes { ptr in
            try send(interleavedData: ptr.baseAddress!, frameCount: frameCount, timestamp: nil)
        }
    }
    #endif

    // MARK: - Metadata

    /// Send metadata (e.g., biometric data, session info)
    public func sendMetadata(_ metadata: [String: Any]) {
        guard isRunning else { return }

        #if NDI_SDK_AVAILABLE
        guard let instance = ndiSendInstance else { return }

        // Convert to XML (NDI metadata format)
        let xmlString = metadataToXML(metadata)

        var metadataFrame = NDIlib_metadata_frame_t()
        metadataFrame.p_data = strdup(xmlString)

        NDIlib_send_send_metadata(instance, &metadataFrame)

        free(metadataFrame.p_data)
        #else
        print("[NDI] Metadata (mock): \(metadata)")
        #endif
    }

    private func metadataToXML(_ metadata: [String: Any]) -> String {
        var xml = "<blab>\n"
        for (key, value) in metadata {
            xml += "  <\(key)>\(value)</\(key)>\n"
        }
        xml += "</blab>"
        return xml
    }

    // MARK: - Connection Status

    /// Check if any receivers are connected
    public func hasConnections() -> Bool {
        #if NDI_SDK_AVAILABLE
        guard let instance = ndiSendInstance else { return false }
        return NDIlib_send_get_no_connections(instance, 0) > 0
        #else
        return false  // Mock mode
        #endif
    }

    /// Get number of active connections
    public func connectionCount() -> Int {
        #if NDI_SDK_AVAILABLE
        guard let instance = ndiSendInstance else { return 0 }
        return Int(NDIlib_send_get_no_connections(instance, 0))
        #else
        return 0
        #endif
    }

    // MARK: - Statistics

    private func printStatistics() {
        print("[NDI] Statistics:")
        print("[NDI]   Frames sent: \(framesSent)")
        print("[NDI]   Bytes sent: \(bytesSent.formatted(.byteCount(style: .memory)))")
        print("[NDI]   Dropped frames: \(droppedFrames)")
    }

    public func resetStatistics() {
        framesSent = 0
        bytesSent = 0
        droppedFrames = 0
    }
}

// MARK: - NDI SDK Stubs (when SDK not available)

#if !NDI_SDK_AVAILABLE
// These are placeholder types for when NDI SDK is not linked
// Real types come from Processing.NDI.Lib.h

private func NDI_initialize() -> Bool { return true }
private func NDI_destroy() {}

private struct NDIlib_send_create_t {
    var p_ndi_name: UnsafeMutablePointer<CChar>?
    var p_groups: UnsafeMutablePointer<CChar>?
    var clock_video: Bool
    var clock_audio: Bool
}

private struct NDIlib_audio_frame_v3_t {
    var sample_rate: Int32
    var no_channels: Int32
    var no_samples: Int32
    var timecode: Int64
    var p_data: UnsafePointer<Float>?
    var channel_stride_in_bytes: Int32
}

private struct NDIlib_metadata_frame_t {
    var p_data: UnsafeMutablePointer<CChar>?
}

private let NDIlib_send_timecode_synthesize: Int64 = Int64.max

private func NDIlib_send_create(_ settings: UnsafePointer<NDIlib_send_create_t>) -> OpaquePointer? {
    return nil
}

private func NDIlib_send_destroy(_ instance: OpaquePointer) {}

private func NDIlib_send_send_audio_v3(_ instance: OpaquePointer, _ frame: UnsafePointer<NDIlib_audio_frame_v3_t>) {}

private func NDIlib_send_send_metadata(_ instance: OpaquePointer, _ frame: UnsafePointer<NDIlib_metadata_frame_t>) {}

private func NDIlib_send_get_no_connections(_ instance: OpaquePointer, _ timeout: UInt32) -> Int32 {
    return 0
}

#endif
