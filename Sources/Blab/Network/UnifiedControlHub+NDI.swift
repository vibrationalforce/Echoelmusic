import Foundation
import Combine

/// NDI Extension for UnifiedControlHub
/// Adds centralized NDI control to the unified control system
///
/// Features:
/// - Enable/Disable NDI streaming from control hub
/// - Automatic device discovery management
/// - Biometric data integration with NDI metadata
/// - Connection monitoring
///
/// Usage:
/// ```swift
/// try hub.enableNDI()
/// // Audio + biometric data now streaming to NDI
/// hub.disableNDI()
/// ```
@available(iOS 15.0, *)
@MainActor
extension UnifiedControlHub {

    // MARK: - NDI Properties (Associated Objects)

    private static var ndiDiscoveryKey: UInt8 = 0
    private static var ndiEnabledKey: UInt8 = 0

    /// NDI device discovery instance
    private var ndiDiscovery: NDIDeviceDiscovery? {
        get {
            objc_getAssociatedObject(self, &Self.ndiDiscoveryKey) as? NDIDeviceDiscovery
        }
        set {
            objc_setAssociatedObject(self, &Self.ndiDiscoveryKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    /// Whether NDI is currently enabled
    public var isNDIEnabled: Bool {
        get {
            objc_getAssociatedObject(self, &Self.ndiEnabledKey) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, &Self.ndiEnabledKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    // MARK: - NDI Control

    /// Enable NDI audio streaming and device discovery
    /// - Throws: NDIAudioSender.NDIError if initialization fails
    public func enableNDI() throws {
        guard !isNDIEnabled else {
            print("[UnifiedControlHub] NDI already enabled")
            return
        }

        // Enable NDI on audio engine
        guard let audioEngine = audioEngine else {
            throw NSError(
                domain: "com.blab.ndi",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "AudioEngine not available"]
            )
        }

        try audioEngine.enableNDI()

        // Start device discovery
        let discovery = NDIDeviceDiscovery()
        discovery.start()
        ndiDiscovery = discovery

        // Subscribe to device changes (for monitoring)
        discovery.$devices
            .sink { [weak self] devices in
                self?.handleNDIDeviceDiscovery(devices)
            }
            .store(in: &cancellables)

        isNDIEnabled = true

        print("[UnifiedControlHub] ✅ NDI enabled")
        print("[UnifiedControlHub]    Source: \(NDIConfiguration.shared.sourceName)")
        print("[UnifiedControlHub]    Format: \(NDIConfiguration.shared.sampleRate) Hz, \(NDIConfiguration.shared.channelCount) ch")
    }

    /// Disable NDI streaming and device discovery
    public func disableNDI() {
        guard isNDIEnabled else {
            print("[UnifiedControlHub] NDI already disabled")
            return
        }

        // Disable NDI on audio engine
        audioEngine?.disableNDI()

        // Stop device discovery
        ndiDiscovery?.stop()
        ndiDiscovery = nil

        isNDIEnabled = false

        print("[UnifiedControlHub] NDI disabled")
    }

    /// Toggle NDI on/off
    public func toggleNDI() {
        if isNDIEnabled {
            disableNDI()
        } else {
            do {
                try enableNDI()
            } catch {
                print("[UnifiedControlHub] ❌ Failed to enable NDI: \(error)")
            }
        }
    }

    // MARK: - Device Discovery

    /// Get list of discovered NDI devices
    public var discoveredNDIDevices: [NDIDeviceDiscovery.NDIDevice] {
        return ndiDiscovery?.devices ?? []
    }

    /// Manually add an NDI device
    public func addNDIDevice(name: String, ipAddress: String, port: UInt16 = 5960) {
        ndiDiscovery?.addDevice(name: name, ipAddress: ipAddress, port: port)
        print("[UnifiedControlHub] Added NDI device: \(name) at \(ipAddress):\(port)")
    }

    /// Remove an NDI device
    public func removeNDIDevice(id: String) {
        ndiDiscovery?.removeDevice(id: id)
        print("[UnifiedControlHub] Removed NDI device: \(id)")
    }

    // MARK: - Connection Status

    /// Get number of NDI receivers currently connected
    public var ndiConnectionCount: Int {
        return audioEngine?.ndiConnectionCount ?? 0
    }

    /// Check if any NDI receivers are connected
    public var hasNDIConnections: Bool {
        return audioEngine?.hasNDIConnections ?? false
    }

    // MARK: - Configuration

    /// Apply NDI preset (Low Latency, Balanced, High Quality, Broadcast)
    public func applyNDIPreset(_ preset: NDIConfiguration.Preset) {
        audioEngine?.applyNDIPreset(preset)
        print("[UnifiedControlHub] Applied NDI preset: \(preset.rawValue)")
    }

    /// Set NDI source name
    public func setNDISourceName(_ name: String) {
        audioEngine?.setNDISourceName(name)
        print("[UnifiedControlHub] NDI source name: \(name)")
    }

    /// Enable/disable biometric metadata in NDI stream
    public func setNDIBiometricMetadata(enabled: Bool) {
        NDIConfiguration.shared.sendBiometricMetadata = enabled
        print("[UnifiedControlHub] NDI biometric metadata: \(enabled ? "enabled" : "disabled")")

        // Restart NDI if running
        if isNDIEnabled {
            disableNDI()
            try? enableNDI()
        }
    }

    // MARK: - Statistics

    /// Get NDI streaming statistics
    public var ndiStatistics: (framesSent: UInt64, bytesSent: UInt64, droppedFrames: UInt64)? {
        return audioEngine?.ndiStatistics
    }

    /// Print NDI statistics to console
    public func printNDIStatistics() {
        guard let stats = ndiStatistics else {
            print("[UnifiedControlHub] NDI not running")
            return
        }

        print("""
        [UnifiedControlHub] NDI Statistics:
          Frames sent: \(stats.framesSent)
          Bytes sent: \(stats.bytesSent.formatted(.byteCount(style: .memory)))
          Dropped frames: \(stats.droppedFrames)
          Connections: \(ndiConnectionCount)
        """)
    }

    // MARK: - Private Handlers

    private func handleNDIDeviceDiscovery(_ devices: [NDIDeviceDiscovery.NDIDevice]) {
        print("[UnifiedControlHub] NDI devices discovered: \(devices.count)")

        for device in devices {
            print("[UnifiedControlHub]   - \(device.name) (\(device.ipAddress):\(device.port))")
        }
    }

    // MARK: - Control Loop Integration

    /// Update NDI metadata in control loop
    /// Call this in the main 60 Hz control loop to send periodic metadata
    internal func updateNDI() {
        // Metadata is automatically sent by AudioEngine+NDI timer
        // This method is here for future enhancements (e.g., manual triggers)
    }
}

// MARK: - NDI Quick Setup

@available(iOS 15.0, *)
@MainActor
extension UnifiedControlHub {

    /// Quick setup: Enable NDI with common defaults
    /// - Parameters:
    ///   - sourceName: Name to appear on network (default: "BLAB iOS")
    ///   - preset: Quality preset (default: .balanced)
    ///   - biometricMetadata: Include HRV/HR in stream (default: true)
    public func quickEnableNDI(
        sourceName: String = "BLAB iOS",
        preset: NDIConfiguration.Preset = .balanced,
        biometricMetadata: Bool = true
    ) {
        // Configure
        setNDISourceName(sourceName)
        applyNDIPreset(preset)
        setNDIBiometricMetadata(enabled: biometricMetadata)

        // Enable
        do {
            try enableNDI()
            print("[UnifiedControlHub] 🚀 NDI quick setup complete!")
        } catch {
            print("[UnifiedControlHub] ❌ NDI quick setup failed: \(error)")
        }
    }
}
