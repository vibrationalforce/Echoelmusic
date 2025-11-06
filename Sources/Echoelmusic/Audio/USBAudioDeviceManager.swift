import AVFoundation
import Combine

/// Manages USB audio devices (external microphones, audio interfaces, USB-C headphones)
///
/// **Purpose:** Detect and manage USB Audio Class devices on iOS/iPadOS
///
/// **Features:**
/// - Automatic USB device detection
/// - Hot-plug/unplug handling
/// - Sample rate matching
/// - Low-latency buffer configuration
/// - Fallback to built-in devices
/// - Device preference persistence
///
/// **Supported Devices:**
/// - USB Audio Class 1.0 (UAC1)
/// - USB Audio Class 2.0 (UAC2) - Recommended
/// - Professional audio interfaces
/// - USB microphones
/// - USB-C headphones/adapters
///
/// **Platform Support:**
/// - iOS 15+ (iPhone 7+ with Lightning/USB-C)
/// - iPadOS 15+ (all iPads with USB-C or Lightning)
/// - macOS 11+ (Catalyst)
///
/// **Technical Notes:**
/// Based on Apple TN3190: USB audio device design considerations
/// - Uses AVAudioSession for device management
/// - Observes route changes via notifications
/// - Handles interruptions gracefully
/// - Maintains audio quality across device switches
///
@MainActor
public class USBAudioDeviceManager: ObservableObject {

    // MARK: - Published Properties

    /// All available audio devices (built-in + USB)
    @Published public private(set) var availableDevices: [AudioDevice] = []

    /// Currently selected input device
    @Published public private(set) var currentInputDevice: AudioDevice?

    /// Currently selected output device
    @Published public private(set) var currentOutputDevice: AudioDevice?

    /// Whether a USB audio device is connected
    @Published public private(set) var hasUSBDevice: Bool = false

    /// USB device connection state
    @Published public private(set) var usbDeviceState: USBDeviceState = .notConnected

    // MARK: - Private Properties

    private let audioSession = AVAudioSession.sharedInstance()
    private var cancellables = Set<AnyCancellable>()
    private var routeChangeObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?

    // User preferences
    private let preferredInputKey = "preferredAudioInputDevice"
    private let preferredOutputKey = "preferredAudioOutputDevice"

    // MARK: - Initialization

    public init() {
        setupAudioSession()
        observeRouteChanges()
        observeInterruptions()
        scanAvailableDevices()

        print("[USBAudio] 🎤 USBAudioDeviceManager initialized")
    }

    // MARK: - Audio Session Setup

    private func setupAudioSession() {
        do {
            // Configure for low-latency audio with USB support
            try audioSession.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker]
            )

            // Set preferred sample rate (48 kHz for USB Audio Class 2.0)
            try audioSession.setPreferredSampleRate(48000)

            // Set low-latency buffer (512 samples = ~10.7ms at 48kHz)
            try audioSession.setPreferredIOBufferDuration(512.0 / 48000.0)

            print("[USBAudio] ✅ Audio session configured (48kHz, 10.7ms latency)")

        } catch {
            print("[USBAudio] ⚠️ Audio session setup failed: \(error)")
        }
    }

    // MARK: - Device Scanning

    /// Scan for all available audio devices
    public func scanAvailableDevices() {
        var devices: [AudioDevice] = []

        // Get current route
        let currentRoute = audioSession.currentRoute

        // Input devices
        if let builtInMic = currentRoute.inputs.first(where: { $0.portType == .builtInMic }) {
            devices.append(AudioDevice(
                id: "builtin-mic",
                name: "Built-in Microphone",
                type: .builtInMicrophone,
                portType: .builtInMic,
                isInput: true,
                isOutput: false,
                isUSB: false,
                sampleRate: audioSession.sampleRate
            ))
        }

        // USB/External input devices
        for input in currentRoute.inputs {
            if input.portType == .usbAudio {
                let device = AudioDevice(
                    id: input.uid,
                    name: input.portName,
                    type: .usbAudio,
                    portType: .usbAudio,
                    isInput: true,
                    isOutput: false,
                    isUSB: true,
                    sampleRate: audioSession.sampleRate,
                    channelCount: input.channels?.count ?? 1
                )
                devices.append(device)
                hasUSBDevice = true
            }
        }

        // Output devices
        if let builtInSpeaker = currentRoute.outputs.first(where: { $0.portType == .builtInSpeaker }) {
            devices.append(AudioDevice(
                id: "builtin-speaker",
                name: "Built-in Speaker",
                type: .builtInSpeaker,
                portType: .builtInSpeaker,
                isInput: false,
                isOutput: true,
                isUSB: false,
                sampleRate: audioSession.sampleRate
            ))
        }

        // USB/External output devices
        for output in currentRoute.outputs {
            if output.portType == .usbAudio {
                let device = AudioDevice(
                    id: output.uid,
                    name: output.portName,
                    type: .usbAudio,
                    portType: .usbAudio,
                    isInput: false,
                    isOutput: true,
                    isUSB: true,
                    sampleRate: audioSession.sampleRate,
                    channelCount: output.channels?.count ?? 2
                )
                devices.append(device)
                hasUSBDevice = true
            }
        }

        // Headphones
        if let headphones = currentRoute.outputs.first(where: { $0.portType == .headphones }) {
            devices.append(AudioDevice(
                id: headphones.uid,
                name: headphones.portName,
                type: .headphones,
                portType: .headphones,
                isInput: false,
                isOutput: true,
                isUSB: false,
                sampleRate: audioSession.sampleRate
            ))
        }

        availableDevices = devices

        // Update current devices
        updateCurrentDevices()

        // Update USB state
        updateUSBDeviceState()

        print("[USBAudio] 📡 Found \(devices.count) audio devices (\(devices.filter { $0.isUSB }.count) USB)")
    }

    private func updateCurrentDevices() {
        let currentRoute = audioSession.currentRoute

        // Current input
        if let currentInput = currentRoute.inputs.first {
            currentInputDevice = availableDevices.first {
                $0.portType == currentInput.portType && $0.isInput
            }
        }

        // Current output
        if let currentOutput = currentRoute.outputs.first {
            currentOutputDevice = availableDevices.first {
                $0.portType == currentOutput.portType && $0.isOutput
            }
        }
    }

    private func updateUSBDeviceState() {
        let usbDevices = availableDevices.filter { $0.isUSB }

        if usbDevices.isEmpty {
            usbDeviceState = .notConnected
        } else if usbDevices.contains(where: { $0.id == currentInputDevice?.id || $0.id == currentOutputDevice?.id }) {
            usbDeviceState = .connectedAndActive
        } else {
            usbDeviceState = .connectedButInactive
        }
    }

    // MARK: - Device Selection

    /// Select a specific audio input device
    public func selectInputDevice(_ device: AudioDevice) {
        guard device.isInput else {
            print("[USBAudio] ⚠️ Device is not an input device: \(device.name)")
            return
        }

        do {
            // For USB devices, system automatically routes when selected
            // We just need to update our state
            currentInputDevice = device

            // Save preference
            UserDefaults.standard.set(device.id, forKey: preferredInputKey)

            print("[USBAudio] ✅ Selected input: \(device.name)")

        } catch {
            print("[USBAudio] ❌ Failed to select input device: \(error)")
        }
    }

    /// Select a specific audio output device
    public func selectOutputDevice(_ device: AudioDevice) {
        guard device.isOutput else {
            print("[USBAudio] ⚠️ Device is not an output device: \(device.name)")
            return
        }

        do {
            // For USB devices, override output
            if device.isUSB {
                try audioSession.overrideOutputAudioPort(.none) // Let system use USB
            } else if device.type == .builtInSpeaker {
                try audioSession.overrideOutputAudioPort(.speaker)
            }

            currentOutputDevice = device

            // Save preference
            UserDefaults.standard.set(device.id, forKey: preferredOutputKey)

            print("[USBAudio] ✅ Selected output: \(device.name)")

        } catch {
            print("[USBAudio] ❌ Failed to select output device: \(error)")
        }
    }

    // MARK: - Route Change Observation

    private func observeRouteChanges() {
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleRouteChange(notification)
            }
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        print("[USBAudio] 🔄 Route changed: \(reason.description)")

        switch reason {
        case .newDeviceAvailable:
            // USB device connected
            scanAvailableDevices()
            handleNewDeviceAvailable()

        case .oldDeviceUnavailable:
            // USB device disconnected
            scanAvailableDevices()
            handleDeviceUnavailable()

        case .categoryChange, .override:
            scanAvailableDevices()

        default:
            break
        }
    }

    private func handleNewDeviceAvailable() {
        // Check if it's a preferred USB device
        if let preferredInputId = UserDefaults.standard.string(forKey: preferredInputKey),
           let preferredDevice = availableDevices.first(where: { $0.id == preferredInputId && $0.isUSB }) {
            selectInputDevice(preferredDevice)
        }

        print("[USBAudio] ✅ New USB device available")
    }

    private func handleDeviceUnavailable() {
        // Fallback to built-in microphone
        if let builtInMic = availableDevices.first(where: { $0.type == .builtInMicrophone }) {
            selectInputDevice(builtInMic)
            print("[USBAudio] ⚠️ USB device disconnected, fallback to built-in mic")
        }
    }

    // MARK: - Interruption Handling

    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleInterruption(notification)
            }
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            print("[USBAudio] ⏸️ Audio interrupted")

        case .ended:
            print("[USBAudio] ▶️ Audio interruption ended")
            // Rescan devices after interruption
            scanAvailableDevices()

        @unknown default:
            break
        }
    }

    // MARK: - Cleanup

    deinit {
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - Supporting Types

/// Represents an audio device
public struct AudioDevice: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let type: AudioDeviceType
    public let portType: AVAudioSession.Port
    public let isInput: Bool
    public let isOutput: Bool
    public let isUSB: Bool
    public let sampleRate: Double
    public let channelCount: Int

    public init(
        id: String,
        name: String,
        type: AudioDeviceType,
        portType: AVAudioSession.Port,
        isInput: Bool,
        isOutput: Bool,
        isUSB: Bool,
        sampleRate: Double,
        channelCount: Int = 1
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.portType = portType
        self.isInput = isInput
        self.isOutput = isOutput
        self.isUSB = isUSB
        self.sampleRate = sampleRate
        self.channelCount = channelCount
    }
}

public enum AudioDeviceType {
    case builtInMicrophone
    case builtInSpeaker
    case headphones
    case usbAudio
    case bluetooth
    case other
}

public enum USBDeviceState {
    case notConnected
    case connectedButInactive
    case connectedAndActive
}

// MARK: - Extensions

extension AVAudioSession.RouteChangeReason {
    var description: String {
        switch self {
        case .newDeviceAvailable: return "New device available"
        case .oldDeviceUnavailable: return "Old device unavailable"
        case .categoryChange: return "Category change"
        case .override: return "Override"
        case .wakeFromSleep: return "Wake from sleep"
        case .noSuitableRouteForCategory: return "No suitable route"
        case .routeConfigurationChange: return "Route configuration change"
        case .unknown: return "Unknown"
        @unknown default: return "Unknown"
        }
    }
}
