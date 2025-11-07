import Foundation
import AVFoundation

#if targetEnvironment(macCatalyst)
import UIKit
#endif

/// Continuity Camera manager for Mac
///
/// **Purpose:** Enable iPhone as wireless camera for Mac face tracking
///
/// **Features:**
/// - Detect Continuity Camera devices
/// - Prefer iPhone camera over built-in Mac camera
/// - Automatic fallback to Mac camera
/// - Device selection UI
/// - Connection status monitoring
///
/// **Platform:** macOS 13.0+ (Catalyst), iOS 16.0+ (companion)
///
/// **Use Cases:**
/// - Face tracking with better iPhone cameras
/// - Wireless camera setup (no cables)
/// - Studio-quality webcam for desktop sessions
/// - Automatic device discovery
///
@available(macOS 13.0, iOS 16.0, *)
@MainActor
public class ContinuityCameraManager: ObservableObject {

    // MARK: - Published Properties

    /// Available camera devices
    @Published public private(set) var availableDevices: [CameraDevice] = []

    /// Currently selected device
    @Published public private(set) var selectedDevice: CameraDevice?

    /// Whether Continuity Camera is available
    @Published public private(set) var isContinuityCameraAvailable: Bool = false

    /// Whether an iPhone camera is connected
    @Published public private(set) var isIPhoneConnected: Bool = false

    /// Connection status
    @Published public private(set) var connectionStatus: ConnectionStatus = .disconnected

    // MARK: - Private Properties

    private var discoverySession: AVCaptureDevice.DiscoverySession?

    // MARK: - Initialization

    public init() {
        #if targetEnvironment(macCatalyst)
        checkContinuityCameraAvailability()
        discoverCameras()
        setupObservers()
        #endif

        print("[ContinuityCamera] 📷 Continuity Camera manager initialized")
    }

    // MARK: - Camera Discovery

    private func checkContinuityCameraAvailability() {
        #if targetEnvironment(macCatalyst)
        // Check if running on macOS 13+
        if #available(macOS 13.0, *) {
            isContinuityCameraAvailable = true
            print("[ContinuityCamera] ✅ Continuity Camera available")
        } else {
            isContinuityCameraAvailable = false
            print("[ContinuityCamera] ⚠️ Continuity Camera requires macOS 13+")
        }
        #else
        isContinuityCameraAvailable = false
        #endif
    }

    private func discoverCameras() {
        #if targetEnvironment(macCatalyst)
        // Create discovery session for video devices
        discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera,
                .external // Continuity Camera appears as external
            ],
            mediaType: .video,
            position: .unspecified
        )

        guard let session = discoverySession else { return }

        // Map devices
        var devices: [CameraDevice] = []

        for device in session.devices {
            let cameraDevice = CameraDevice(
                id: device.uniqueID,
                name: device.localizedName,
                type: detectDeviceType(device),
                position: device.position,
                avDevice: device
            )
            devices.append(cameraDevice)
        }

        availableDevices = devices

        // Check if iPhone is connected
        isIPhoneConnected = devices.contains { $0.type == .iPhone }

        // Auto-select best device
        autoSelectDevice()

        print("[ContinuityCamera] 📷 Discovered \(devices.count) cameras")
        for device in devices {
            print("[ContinuityCamera]   - \(device.name) (\(device.type))")
        }
        #endif
    }

    private func detectDeviceType(_ device: AVCaptureDevice) -> CameraDeviceType {
        let name = device.localizedName.lowercased()

        if name.contains("iphone") {
            return .iPhone
        } else if name.contains("ipad") {
            return .iPad
        } else if name.contains("continuity") {
            return .continuityCameraGeneric
        } else if device.position == .front || device.position == .back {
            return .builtIn
        } else {
            return .external
        }
    }

    // MARK: - Device Selection

    /// Auto-select best available camera
    private func autoSelectDevice() {
        // Priority:
        // 1. iPhone (best quality)
        // 2. iPad
        // 3. Built-in Mac camera
        // 4. External camera

        if let iPhone = availableDevices.first(where: { $0.type == .iPhone }) {
            selectDevice(iPhone)
        } else if let iPad = availableDevices.first(where: { $0.type == .iPad }) {
            selectDevice(iPad)
        } else if let builtIn = availableDevices.first(where: { $0.type == .builtIn }) {
            selectDevice(builtIn)
        } else if let external = availableDevices.first {
            selectDevice(external)
        }
    }

    /// Select specific camera device
    public func selectDevice(_ device: CameraDevice) {
        selectedDevice = device
        connectionStatus = .connected

        print("[ContinuityCamera] ✅ Selected: \(device.name)")

        // Notify app to reconfigure camera input
        NotificationCenter.default.post(
            name: .cameraDeviceChanged,
            object: device
        )
    }

    /// Get AVCaptureDevice for selected camera
    public func getSelectedAVDevice() -> AVCaptureDevice? {
        return selectedDevice?.avDevice
    }

    // MARK: - Refresh

    /// Manually refresh camera list
    public func refreshDevices() {
        discoverCameras()
        print("[ContinuityCamera] 🔄 Devices refreshed")
    }

    // MARK: - Observers

    private func setupObservers() {
        #if targetEnvironment(macCatalyst)
        // Monitor device connections/disconnections
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeviceConnected),
            name: .AVCaptureDeviceWasConnected,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeviceDisconnected),
            name: .AVCaptureDeviceWasDisconnected,
            object: nil
        )

        print("[ContinuityCamera] 📡 Device observers configured")
        #endif
    }

    @objc private func handleDeviceConnected(_ notification: Notification) {
        guard let device = notification.object as? AVCaptureDevice else { return }

        print("[ContinuityCamera] 🔌 Device connected: \(device.localizedName)")

        // Refresh device list
        refreshDevices()

        // If iPhone connected, auto-select it
        if device.localizedName.lowercased().contains("iphone") {
            if let iPhoneDevice = availableDevices.first(where: { $0.type == .iPhone }) {
                selectDevice(iPhoneDevice)
            }
        }
    }

    @objc private func handleDeviceDisconnected(_ notification: Notification) {
        guard let device = notification.object as? AVCaptureDevice else { return }

        print("[ContinuityCamera] 🔌 Device disconnected: \(device.localizedName)")

        // Refresh device list
        refreshDevices()

        // If selected device was disconnected, auto-select another
        if selectedDevice?.id == device.uniqueID {
            autoSelectDevice()
        }
    }

    // MARK: - Connection Status

    /// Check if Continuity Camera is connected
    public func checkConnection() {
        if isIPhoneConnected || availableDevices.contains(where: { $0.type == .iPhone || $0.type == .iPad }) {
            connectionStatus = .connected
        } else if !availableDevices.isEmpty {
            connectionStatus = .connected
        } else {
            connectionStatus = .disconnected
        }
    }

    // MARK: - Debugging

    /// Print current camera status
    public func printCameraStatus() {
        print("[ContinuityCamera] 📊 Camera Status:")
        print("  Available: \(isContinuityCameraAvailable)")
        print("  iPhone Connected: \(isIPhoneConnected)")
        print("  Total Devices: \(availableDevices.count)")

        for device in availableDevices {
            print("    - \(device.name) (\(device.type))")
        }

        if let selected = selectedDevice {
            print("  Selected: \(selected.name)")
        } else {
            print("  Selected: None")
        }
    }
}

// MARK: - Supporting Types

@available(macOS 13.0, iOS 16.0, *)
public struct CameraDevice: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let type: CameraDeviceType
    public let position: AVCaptureDevice.Position
    public let avDevice: AVCaptureDevice

    public static func == (lhs: CameraDevice, rhs: CameraDevice) -> Bool {
        return lhs.id == rhs.id
    }
}

@available(macOS 13.0, iOS 16.0, *)
public enum CameraDeviceType: String {
    case iPhone = "iPhone"
    case iPad = "iPad"
    case builtIn = "Built-in"
    case external = "External"
    case continuityCameraGeneric = "Continuity Camera"

    var icon: String {
        switch self {
        case .iPhone:
            return "iphone"
        case .iPad:
            return "ipad"
        case .builtIn:
            return "camera"
        case .external:
            return "camera.fill"
        case .continuityCameraGeneric:
            return "camera.metering.multispot"
        }
    }

    var displayName: String {
        return self.rawValue
    }
}

public enum ConnectionStatus {
    case disconnected
    case connecting
    case connected
    case error

    var displayName: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .error:
            return "Error"
        }
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let cameraDeviceChanged = Notification.Name("cameraDeviceChanged")
}

// MARK: - SwiftUI Integration

#if targetEnvironment(macCatalyst)
import SwiftUI

@available(macOS 13.0, *)
public struct CameraDevicePickerView: View {
    @StateObject private var cameraManager = ContinuityCameraManager()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "camera")
                    .font(.title2)
                    .foregroundColor(.blue)

                Text("Camera Selection")
                    .font(.headline)

                Spacer()

                Button(action: {
                    cameraManager.refreshDevices()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                }
            }

            if cameraManager.isContinuityCameraAvailable {
                // Continuity Camera info
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)

                    Text("Use your iPhone as a high-quality webcam")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }

            // Device list
            if cameraManager.availableDevices.isEmpty {
                Text("No cameras available")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(cameraManager.availableDevices) { device in
                    DeviceRow(
                        device: device,
                        isSelected: cameraManager.selectedDevice?.id == device.id,
                        onSelect: {
                            cameraManager.selectDevice(device)
                        }
                    )
                }
            }
        }
        .padding()
    }
}

@available(macOS 13.0, *)
struct DeviceRow: View {
    let device: CameraDevice
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: device.type.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : .blue)

                VStack(alignment: .leading) {
                    Text(device.name)
                        .font(.body)
                        .foregroundColor(isSelected ? .white : .primary)

                    Text(device.type.displayName)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(isSelected ? Color.blue : Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
#endif
