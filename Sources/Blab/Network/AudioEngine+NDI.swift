import Foundation
import AVFoundation
import Combine

/// NDI Extension for AudioEngine
/// Adds NDI audio streaming capabilities to the main audio engine
///
/// Features:
/// - Real-time audio streaming to NDI network
/// - Automatic format conversion
/// - Biometric metadata embedding
/// - Zero-copy audio buffer forwarding
///
/// Usage:
/// ```swift
/// audioEngine.enableNDI()
/// // Audio now streams to network as "BLAB iOS"
/// audioEngine.disableNDI()
/// ```
@available(iOS 15.0, *)
extension AudioEngine {

    // MARK: - NDI Properties

    private static var ndiSenderKey: UInt8 = 0
    private static var ndiTapNodeKey: UInt8 = 0
    private static var ndiMetadataTimerKey: UInt8 = 0

    private var ndiSender: NDIAudioSender? {
        get {
            objc_getAssociatedObject(self, &Self.ndiSenderKey) as? NDIAudioSender
        }
        set {
            objc_setAssociatedObject(self, &Self.ndiSenderKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    private var ndiTapNode: AVAudioMixerNode? {
        get {
            objc_getAssociatedObject(self, &Self.ndiTapNodeKey) as? AVAudioMixerNode
        }
        set {
            objc_setAssociatedObject(self, &Self.ndiTapNodeKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    private var ndiMetadataTimer: Timer? {
        get {
            objc_getAssociatedObject(self, &Self.ndiMetadataTimerKey) as? Timer
        }
        set {
            objc_setAssociatedObject(self, &Self.ndiMetadataTimerKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    // MARK: - NDI Control

    /// Enable NDI audio streaming
    /// Audio from AudioEngine will be sent to NDI network
    func enableNDI() throws {
        // Check if already enabled
        if ndiSender?.isRunning == true {
            print("[NDI] Already enabled")
            return
        }

        let config = NDIConfiguration.shared

        // Validate configuration
        let warnings = config.validate()
        if !warnings.isEmpty {
            print("[NDI] ⚠️ Configuration warnings:")
            warnings.forEach { print("[NDI]   - \($0)") }
        }

        // Create NDI sender
        let sender = NDIAudioSender(
            sourceName: config.sourceName,
            audioFormat: config.audioFormat()
        )

        // Start sender
        try sender.start()
        ndiSender = sender

        // Setup audio tap
        try setupNDIAudioTap()

        // Start metadata timer (if biometric metadata enabled)
        if config.sendBiometricMetadata {
            startMetadataTimer()
        }

        print("[NDI] ✅ Enabled - streaming as '\(config.sourceName)'")
    }

    /// Disable NDI audio streaming
    func disableNDI() {
        // Stop metadata timer
        ndiMetadataTimer?.invalidate()
        ndiMetadataTimer = nil

        // Remove audio tap
        removeNDIAudioTap()

        // Stop sender
        ndiSender?.stop()
        ndiSender = nil

        print("[NDI] Disabled")
    }

    /// Toggle NDI on/off
    func toggleNDI() {
        if ndiSender?.isRunning == true {
            disableNDI()
        } else {
            do {
                try enableNDI()
            } catch {
                print("[NDI] ❌ Failed to enable: \(error)")
            }
        }
    }

    /// Check if NDI is currently streaming
    var isNDIEnabled: Bool {
        return ndiSender?.isRunning == true
    }

    // MARK: - Audio Tap Setup

    private func setupNDIAudioTap() throws {
        guard let sender = ndiSender else {
            throw NDIAudioSender.NDIError.notStarted
        }

        // Get audio format from microphone manager
        guard let micFormat = microphoneManager.avAudioEngine?.outputNode.outputFormat(forBus: 0) else {
            throw NDIAudioSender.NDIError.invalidAudioFormat
        }

        print("[NDI] Tap format: \(micFormat.sampleRate) Hz, \(micFormat.channelCount) ch")

        // Create NDI format (may need conversion)
        let ndiFormat = AVAudioFormat(
            standardFormatWithSampleRate: sender.audioFormat.sampleRate,
            channels: AVAudioChannelCount(sender.audioFormat.channelCount)
        )

        guard let ndiFormat = ndiFormat else {
            throw NDIAudioSender.NDIError.invalidAudioFormat
        }

        // Create tap node (mixer for zero-copy forwarding)
        let tapNode = AVAudioMixerNode()
        ndiTapNode = tapNode

        // Install tap on microphone output
        microphoneManager.avAudioEngine?.outputNode.installTap(
            onBus: 0,
            bufferSize: UInt32(NDIConfiguration.shared.bufferSize),
            format: micFormat
        ) { [weak self, weak sender] buffer, time in
            guard let self = self, let sender = sender else { return }

            // Convert format if needed
            if micFormat.sampleRate != ndiFormat.sampleRate {
                // Need sample rate conversion
                self.sendWithConversion(buffer: buffer, sender: sender, targetFormat: ndiFormat)
            } else {
                // Direct send (zero-copy)
                self.sendDirect(buffer: buffer, sender: sender)
            }
        }

        print("[NDI] Audio tap installed")
    }

    private func removeNDIAudioTap() {
        // Remove tap from output node
        microphoneManager.avAudioEngine?.outputNode.removeTap(onBus: 0)
        ndiTapNode = nil
        print("[NDI] Audio tap removed")
    }

    // MARK: - Audio Sending

    private func sendDirect(buffer: AVAudioPCMBuffer, sender: NDIAudioSender) {
        // Send buffer directly to NDI (zero-copy)
        do {
            try sender.send(audioBuffer: buffer)
        } catch {
            print("[NDI] ⚠️ Failed to send audio: \(error)")
        }
    }

    private func sendWithConversion(buffer: AVAudioPCMBuffer, sender: NDIAudioSender, targetFormat: AVAudioFormat) {
        // Create converter
        guard let converter = AVAudioConverter(from: buffer.format, to: targetFormat) else {
            print("[NDI] ⚠️ Failed to create audio converter")
            return
        }

        // Create output buffer
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * targetFormat.sampleRate / buffer.format.sampleRate)
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            print("[NDI] ⚠️ Failed to create converted buffer")
            return
        }

        var error: NSError?

        // Convert
        let status = converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        if let error = error {
            print("[NDI] ⚠️ Conversion error: \(error)")
            return
        }

        if status == .haveData || status == .endOfStream {
            // Send converted buffer
            sendDirect(buffer: convertedBuffer, sender: sender)
        }
    }

    // MARK: - Metadata

    private func startMetadataTimer() {
        let interval = NDIConfiguration.shared.metadataInterval

        ndiMetadataTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.sendBiometricMetadata()
        }

        print("[NDI] Metadata timer started (interval: \(interval)s)")
    }

    private func sendBiometricMetadata() {
        guard let sender = ndiSender, let healthKit = healthKitManager else {
            return
        }

        // Collect biometric data
        var metadata: [String: Any] = [:]

        // Heart Rate
        if let hr = healthKit.currentHeartRate {
            metadata["heartRate"] = hr
        }

        // HRV
        if let hrv = healthKit.currentHRV {
            metadata["hrv"] = hrv
        }

        // Coherence
        if let coherence = healthKit.coherenceScore {
            metadata["coherence"] = coherence
        }

        // Breathing rate (if available)
        if let breathingRate = healthKit.breathingRate {
            metadata["breathingRate"] = breathingRate
        }

        // Audio info
        metadata["isRunning"] = isRunning
        metadata["spatialAudioEnabled"] = spatialAudioEnabled
        metadata["binauralBeatsEnabled"] = binauralBeatsEnabled

        // Timestamp
        metadata["timestamp"] = Date().timeIntervalSince1970

        // Send to NDI
        sender.sendMetadata(metadata)
    }

    // MARK: - Connection Status

    /// Get number of NDI receivers connected
    var ndiConnectionCount: Int {
        return ndiSender?.connectionCount() ?? 0
    }

    /// Check if any NDI receivers are connected
    var hasNDIConnections: Bool {
        return ndiSender?.hasConnections() ?? false
    }

    // MARK: - Statistics

    /// Get NDI sender statistics
    var ndiStatistics: (framesSent: UInt64, bytesSent: UInt64, droppedFrames: UInt64)? {
        guard let sender = ndiSender else { return nil }
        return (sender.framesSent, sender.bytesSent, sender.droppedFrames)
    }
}

// MARK: - NDI Configuration Helpers

@available(iOS 15.0, *)
extension AudioEngine {

    /// Apply NDI preset configuration
    func applyNDIPreset(_ preset: NDIConfiguration.Preset) {
        NDIConfiguration.shared.applyPreset(preset)

        // Restart NDI if running
        if isNDIEnabled {
            disableNDI()
            try? enableNDI()
        }
    }

    /// Set NDI source name
    func setNDISourceName(_ name: String) {
        NDIConfiguration.shared.sourceName = name

        // Restart NDI if running
        if isNDIEnabled {
            disableNDI()
            try? enableNDI()
        }
    }
}
