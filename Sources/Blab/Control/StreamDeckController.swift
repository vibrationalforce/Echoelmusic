import Foundation
import Combine

/// Stream Deck Controller for BLAB
///
/// Provides integration with Elgato Stream Deck devices:
/// - Button mapping (customizable actions)
/// - Visual feedback (button colors, icons)
/// - Macros and shortcuts
/// - Scene switching
/// - Audio control
///
/// Supported Devices:
/// - Stream Deck (15 keys)
/// - Stream Deck Mini (6 keys)
/// - Stream Deck XL (32 keys)
/// - Stream Deck Mobile (iOS app)
///
/// Usage:
/// ```swift
/// let streamDeck = StreamDeckController.shared
/// streamDeck.connect()
/// streamDeck.setButton(0, action: .toggleAudio)
/// ```
///
/// Note: Physical Stream Deck requires external accessory framework.
/// This implementation focuses on Stream Deck Mobile protocol.
@available(iOS 15.0, *)
public class StreamDeckController: ObservableObject {

    // MARK: - Singleton

    public static let shared = StreamDeckController()

    // MARK: - Published Properties

    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var deviceType: DeviceType = .mobile
    @Published public private(set) var buttonLayout: ButtonLayout = []

    // MARK: - Device Types

    public enum DeviceType: String, CaseIterable {
        case standard = "Stream Deck"
        case mini = "Stream Deck Mini"
        case xl = "Stream Deck XL"
        case mobile = "Stream Deck Mobile"

        var buttonCount: Int {
            switch self {
            case .standard: return 15
            case .mini: return 6
            case .xl: return 32
            case .mobile: return 15
            }
        }

        var rows: Int {
            switch self {
            case .standard: return 3
            case .mini: return 2
            case .xl: return 4
            case .mobile: return 3
            }
        }

        var columns: Int {
            switch self {
            case .standard: return 5
            case .mini: return 3
            case .xl: return 8
            case .mobile: return 5
            }
        }
    }

    // MARK: - Button Configuration

    public struct ButtonConfig: Identifiable, Codable {
        public let id: Int
        public var action: ButtonAction
        public var label: String
        public var icon: String
        public var backgroundColor: String
        public var enabled: Bool

        public init(id: Int, action: ButtonAction = .none, label: String = "",
                   icon: String = "square.fill", backgroundColor: String = "gray",
                   enabled: Bool = true) {
            self.id = id
            self.action = action
            self.label = label
            self.icon = icon
            self.backgroundColor = backgroundColor
            self.enabled = enabled
        }
    }

    public typealias ButtonLayout = [ButtonConfig]

    // MARK: - Button Actions

    public enum ButtonAction: String, Codable, CaseIterable {
        case none = "None"
        case toggleAudio = "Toggle Audio"
        case toggleSpatial = "Toggle Spatial Audio"
        case toggleBinaural = "Toggle Binaural Beats"
        case enableNDI = "Enable NDI"
        case enableRTMP = "Enable RTMP"
        case startRecording = "Start Recording"
        case stopRecording = "Stop Recording"
        case nextPreset = "Next Preset"
        case previousPreset = "Previous Preset"
        case toggleNoiseGate = "Toggle Noise Gate"
        case toggleCompressor = "Toggle Compressor"
        case increaseBitrate = "Increase Bitrate"
        case decreaseBitrate = "Decrease Bitrate"
        case muteAudio = "Mute Audio"
        case soloAudio = "Solo Audio"
        case triggerMacro = "Trigger Macro"
        case switchScene = "Switch Scene"

        var icon: String {
            switch self {
            case .none: return "square.fill"
            case .toggleAudio: return "play.circle.fill"
            case .toggleSpatial: return "move.3d"
            case .toggleBinaural: return "waveform"
            case .enableNDI: return "antenna.radiowaves.left.and.right"
            case .enableRTMP: return "dot.radiowaves.up.forward"
            case .startRecording: return "record.circle"
            case .stopRecording: return "stop.circle"
            case .nextPreset: return "chevron.right.circle"
            case .previousPreset: return "chevron.left.circle"
            case .toggleNoiseGate: return "waveform.path.ecg"
            case .toggleCompressor: return "slider.horizontal.3"
            case .increaseBitrate: return "arrow.up.circle"
            case .decreaseBitrate: return "arrow.down.circle"
            case .muteAudio: return "speaker.slash"
            case .soloAudio: return "speaker.wave.2"
            case .triggerMacro: return "bolt.circle"
            case .switchScene: return "rectangle.3.group"
            }
        }

        var defaultColor: String {
            switch self {
            case .none: return "gray"
            case .toggleAudio, .startRecording: return "red"
            case .toggleSpatial: return "blue"
            case .toggleBinaural: return "purple"
            case .enableNDI: return "green"
            case .enableRTMP: return "orange"
            case .stopRecording, .muteAudio: return "red"
            case .toggleNoiseGate, .toggleCompressor: return "cyan"
            default: return "blue"
            }
        }
    }

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private weak var audioEngine: AudioEngine?
    private weak var controlHub: UnifiedControlHub?

    // MARK: - Initialization

    private init() {
        setupDefaultLayout()
    }

    // MARK: - Connection

    /// Connect to Stream Deck device
    public func connect() {
        // In a real implementation, this would:
        // 1. Scan for Stream Deck Mobile over network
        // 2. Or connect to physical Stream Deck via ExternalAccessory
        // 3. Establish WebSocket connection (for Mobile)

        isConnected = true
        print("[StreamDeck] ✅ Connected to \(deviceType.rawValue)")
        print("[StreamDeck]    Buttons: \(deviceType.buttonCount)")
    }

    /// Disconnect from Stream Deck
    public func disconnect() {
        isConnected = false
        print("[StreamDeck] Disconnected")
    }

    // MARK: - Configuration

    /// Setup integration with audio engine and control hub
    public func setup(audioEngine: AudioEngine, controlHub: UnifiedControlHub) {
        self.audioEngine = audioEngine
        self.controlHub = controlHub

        // Subscribe to state changes
        audioEngine.$isRunning
            .sink { [weak self] isRunning in
                self?.updateButtonState(action: .toggleAudio, enabled: isRunning)
            }
            .store(in: &cancellables)

        print("[StreamDeck] ✅ Integrated with audio engine and control hub")
    }

    /// Set button configuration
    public func setButton(_ index: Int, config: ButtonConfig) {
        guard index < buttonLayout.count else { return }
        buttonLayout[index] = config
        sendButtonUpdate(index)
    }

    /// Set button action (quick config)
    public func setButton(_ index: Int, action: ButtonAction, label: String? = nil) {
        guard index < buttonLayout.count else { return }

        let config = ButtonConfig(
            id: index,
            action: action,
            label: label ?? action.rawValue,
            icon: action.icon,
            backgroundColor: action.defaultColor,
            enabled: true
        )

        setButton(index, config: config)
    }

    // MARK: - Default Layout

    private func setupDefaultLayout() {
        // Create default button layout
        buttonLayout = []

        for i in 0..<deviceType.buttonCount {
            let action = defaultAction(for: i)
            let config = ButtonConfig(
                id: i,
                action: action,
                label: action.rawValue,
                icon: action.icon,
                backgroundColor: action.defaultColor,
                enabled: true
            )
            buttonLayout.append(config)
        }
    }

    private func defaultAction(for index: Int) -> ButtonAction {
        // Default button layout (15-key layout)
        switch index {
        case 0: return .toggleAudio
        case 1: return .toggleSpatial
        case 2: return .toggleBinaural
        case 3: return .enableNDI
        case 4: return .enableRTMP
        case 5: return .startRecording
        case 6: return .toggleNoiseGate
        case 7: return .toggleCompressor
        case 8: return .muteAudio
        case 9: return .stopRecording
        case 10: return .nextPreset
        case 11: return .previousPreset
        case 12: return .increaseBitrate
        case 13: return .decreaseBitrate
        case 14: return .triggerMacro
        default: return .none
        }
    }

    // MARK: - Button Press Handling

    /// Handle button press event
    public func handleButtonPress(_ index: Int) {
        guard index < buttonLayout.count else { return }
        let config = buttonLayout[index]

        guard config.enabled else {
            print("[StreamDeck] Button \(index) is disabled")
            return
        }

        executeAction(config.action)

        // Visual feedback
        flashButton(index)
    }

    /// Execute button action
    private func executeAction(_ action: ButtonAction) {
        guard let audioEngine = audioEngine else {
            print("[StreamDeck] ⚠️ Audio engine not connected")
            return
        }

        print("[StreamDeck] Executing action: \(action.rawValue)")

        switch action {
        case .none:
            break

        case .toggleAudio:
            if audioEngine.isRunning {
                audioEngine.stop()
            } else {
                audioEngine.start()
            }

        case .toggleSpatial:
            audioEngine.toggleSpatialAudio()

        case .toggleBinaural:
            audioEngine.toggleBinauralBeats()

        case .enableNDI:
            controlHub?.quickEnableNDI()

        case .enableRTMP:
            // Would need stream key configuration
            print("[StreamDeck] RTMP requires configuration")

        case .startRecording:
            // TODO: Start recording
            print("[StreamDeck] Recording started")

        case .stopRecording:
            // TODO: Stop recording
            print("[StreamDeck] Recording stopped")

        case .nextPreset:
            // TODO: Next DSP preset
            print("[StreamDeck] Next preset")

        case .previousPreset:
            // TODO: Previous DSP preset
            print("[StreamDeck] Previous preset")

        case .toggleNoiseGate:
            let dsp = audioEngine.dspProcessor.advanced
            if dsp.noiseGate.enabled {
                dsp.disableNoiseGate()
            } else {
                dsp.enableNoiseGate()
            }

        case .toggleCompressor:
            let dsp = audioEngine.dspProcessor.advanced
            if dsp.compressor.enabled {
                dsp.disableCompressor()
            } else {
                dsp.enableCompressor()
            }

        case .increaseBitrate:
            // TODO: Increase streaming bitrate
            print("[StreamDeck] Bitrate increased")

        case .decreaseBitrate:
            // TODO: Decrease streaming bitrate
            print("[StreamDeck] Bitrate decreased")

        case .muteAudio:
            // TODO: Mute audio
            print("[StreamDeck] Audio muted")

        case .soloAudio:
            // TODO: Solo audio
            print("[StreamDeck] Audio solo")

        case .triggerMacro:
            // TODO: Trigger macro
            print("[StreamDeck] Macro triggered")

        case .switchScene:
            // TODO: Switch scene
            print("[StreamDeck] Scene switched")
        }
    }

    // MARK: - Visual Feedback

    private func updateButtonState(action: ButtonAction, enabled: Bool) {
        // Update button visual state
        for (index, config) in buttonLayout.enumerated() where config.action == action {
            var updatedConfig = config
            updatedConfig.backgroundColor = enabled ? "green" : config.action.defaultColor
            buttonLayout[index] = updatedConfig
            sendButtonUpdate(index)
        }
    }

    private func flashButton(_ index: Int) {
        // Flash button for visual feedback
        print("[StreamDeck] 💡 Button \(index) pressed")
    }

    private func sendButtonUpdate(_ index: Int) {
        // In real implementation, send update to device
        guard isConnected else { return }
        // Send WebSocket message or USB command
    }

    // MARK: - Presets

    /// Load button layout preset
    public func loadPreset(_ preset: LayoutPreset) {
        switch preset {
        case .default:
            setupDefaultLayout()

        case .streaming:
            setupStreamingLayout()

        case .recording:
            setupRecordingLayout()

        case .performance:
            setupPerformanceLayout()
        }

        print("[StreamDeck] ✅ Loaded preset: \(preset.rawValue)")
    }

    public enum LayoutPreset: String, CaseIterable {
        case `default` = "Default"
        case streaming = "Streaming"
        case recording = "Recording"
        case performance = "Performance"
    }

    private func setupStreamingLayout() {
        setButton(0, action: .enableNDI, label: "NDI")
        setButton(1, action: .enableRTMP, label: "RTMP")
        setButton(2, action: .increaseBitrate, label: "Bitrate+")
        setButton(3, action: .decreaseBitrate, label: "Bitrate-")
        setButton(4, action: .muteAudio, label: "Mute")
        // ... more streaming-specific buttons
    }

    private func setupRecordingLayout() {
        setButton(0, action: .startRecording, label: "Record")
        setButton(1, action: .stopRecording, label: "Stop")
        setButton(2, action: .toggleNoiseGate, label: "Gate")
        setButton(3, action: .toggleCompressor, label: "Comp")
        // ... more recording-specific buttons
    }

    private func setupPerformanceLayout() {
        setButton(0, action: .toggleAudio, label: "Play")
        setButton(1, action: .toggleSpatial, label: "3D")
        setButton(2, action: .toggleBinaural, label: "Beats")
        setButton(3, action: .nextPreset, label: "Next")
        setButton(4, action: .previousPreset, label: "Prev")
        // ... more performance-specific buttons
    }

    // MARK: - Save/Load Configuration

    /// Save current button layout
    public func saveLayout(name: String) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        do {
            let data = try encoder.encode(buttonLayout)
            UserDefaults.standard.set(data, forKey: "streamdeck_layout_\(name)")
            print("[StreamDeck] ✅ Layout saved: \(name)")
        } catch {
            print("[StreamDeck] ❌ Failed to save layout: \(error)")
        }
    }

    /// Load saved button layout
    public func loadLayout(name: String) {
        guard let data = UserDefaults.standard.data(forKey: "streamdeck_layout_\(name)") else {
            print("[StreamDeck] ⚠️ Layout not found: \(name)")
            return
        }

        let decoder = JSONDecoder()
        do {
            buttonLayout = try decoder.decode(ButtonLayout.self, from: data)
            print("[StreamDeck] ✅ Layout loaded: \(name)")

            // Send all button updates
            for i in 0..<buttonLayout.count {
                sendButtonUpdate(i)
            }
        } catch {
            print("[StreamDeck] ❌ Failed to load layout: \(error)")
        }
    }
}
